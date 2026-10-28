-- Group message actions. Nothing here deletes rows: un-saving is done by the app directly
-- (RLS "own saved"), and restoring a reported message starts a new report count.
alter table public.group_messages add column if not exists reports_reset_at timestamptz;

-- Internal helpers run with the caller's rights: inside the chat functions that is the owner,
-- but called straight from the API, RLS blocks them (no insert policy on strikes / bans).
create or replace function public.apply_strike(p_user uuid, p_rule text, p_excerpt text, p_certain boolean) returns text
language plpgsql security invoker set search_path = '' as $$
declare cnt int; reason text := public.rule_text(p_rule); ph text;
begin
  insert into public.chat_strikes (user_id, rule, excerpt) values (p_user, p_rule, left(coalesce(p_excerpt, ''), 300));
  select count(*) into cnt from public.chat_strikes where user_id = p_user;
  if (p_rule = 'sex' and p_certain) or cnt >= 4 then
    insert into public.chat_bans (user_id, until, reason) values (p_user, null, reason)
      on conflict (user_id) do update set until = null, reason = excluded.reason, created_at = now();
    select phone into ph from public.profiles where id = p_user;
    if ph is not null then insert into public.banned_phones (phone, reason) values (ph, reason) on conflict do nothing; end if;
    return reason || '. Siz chatdan doimiy chetlatildingiz.';
  elsif cnt = 1 then
    return reason || '. Xabar yuborilmadi. Bu birinchi ogohlantirish — keyingi buzilishda 24 soatga cheklanasiz.';
  elsif cnt = 2 then
    insert into public.chat_bans (user_id, until, reason) values (p_user, now() + interval '24 hours', reason)
      on conflict (user_id) do update set until = excluded.until, reason = excluded.reason, created_at = now();
    return reason || '. Siz 24 soat chatga yoza olmaysiz.';
  else
    insert into public.chat_bans (user_id, until, reason) values (p_user, now() + interval '7 days', reason)
      on conflict (user_id) do update set until = excluded.until, reason = excluded.reason, created_at = now();
    return reason || '. Siz 7 kun chatga yoza olmaysiz. Keyingi buzilishda doimiy ban beriladi.';
  end if;
end $$;

create or replace function public.active_ban_text(p_user uuid) returns text
language sql stable security invoker set search_path = '' as $$
  select public.ban_text(until, reason) from public.chat_bans
  where user_id = p_user and (until is null or until > now());
$$;

create or replace function public.voice_left_today(p_user uuid) returns int
language sql stable security invoker set search_path = '' as $$
  select greatest(0, 1 - count(*))::int from public.group_messages
  where user_id = p_user and kind = 'voice' and created_at >= public.moscow_day_start();
$$;

-- save / edit / delete / punish (admin) / pin / unpin / restore (admin)
create or replace function public.group_action(p_id bigint, p_action text, p_body text default null, p_rule text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  adm boolean := public.is_admin();
  msg record;
  rule text;
  note text;
  b text := trim(coalesce(p_body, ''));
begin
  if uid is null then perform public.raise_user_error('Avval hisobga kiring'); end if;
  select * into msg from public.group_messages where id = p_id and deleted_at is null;
  if not found then perform public.raise_user_error('Xabar topilmadi'); end if;

  if p_action = 'save' then
    insert into public.group_saved (user_id, message_id) values (uid, p_id) on conflict do nothing;
  elsif p_action = 'edit' then
    if msg.user_id <> uid then perform public.raise_user_error('Faqat o‘z xabaringizni tahrirlay olasiz'); end if;
    if b = '' and msg.kind = 'text' then perform public.raise_user_error('Xabar bo‘sh'); end if;
    if char_length(b) > 2000 then perform public.raise_user_error('Xabar 2000 belgidan oshmasin'); end if;
    note := public.active_ban_text(uid);
    if note is not null then perform public.raise_user_error(note); end if;
    if not adm then
      if public.has_link(b) then perform public.raise_user_error('Havola joylash faqat admin uchun ruxsat etilgan'); end if;
      rule := public.moderate_text(b);
      if rule is not null then return jsonb_build_object('error', public.apply_strike(uid, rule, b, true)); end if;
    end if;
    update public.group_messages set body = b, edited_at = now() where id = p_id;
  elsif p_action in ('delete', 'punish') then
    if p_action = 'delete' and msg.user_id <> uid and not adm then perform public.raise_user_error('Faqat o‘z xabaringizni o‘chira olasiz'); end if;
    if p_action = 'punish' and not adm then perform public.raise_user_error('Faqat admin uchun'); end if;
    -- the row stays (wiped) so every open chat removes it through Realtime
    update public.group_messages set deleted_at = now(), pinned_at = null, body = '', media_expired = true where id = p_id;
    if p_action = 'punish' then
      note := public.apply_strike(msg.user_id, coalesce(p_rule, 'card'), msg.body, false);
      return jsonb_build_object('ok', true, 'note', note, 'media', jsonb_build_array(msg.media_path, msg.thumb_path));
    end if;
    return jsonb_build_object('ok', true, 'media', jsonb_build_array(msg.media_path, msg.thumb_path));
  elsif p_action in ('pin', 'unpin', 'restore') then
    if not adm then perform public.raise_user_error('Faqat admin uchun'); end if;
    if p_action = 'pin' then
      update public.group_messages set pinned_at = null where city = msg.city and pinned_at is not null;
      update public.group_messages set pinned_at = now(), hidden_at = null where id = p_id;
    elsif p_action = 'unpin' then
      update public.group_messages set pinned_at = null where id = p_id;
    else
      update public.group_messages set hidden_at = null, report_count = 0, reports_reset_at = now() where id = p_id;
    end if;
  else
    perform public.raise_user_error('Noma’lum amal');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- 3 reports (since the last admin restore) hide a message until an admin looks at it
create or replace function public.group_report(p_id bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); msg record; cnt int;
begin
  if uid is null then perform public.raise_user_error('Avval hisobga kiring'); end if;
  select * into msg from public.group_messages where id = p_id and deleted_at is null;
  if not found then perform public.raise_user_error('Xabar topilmadi'); end if;
  if msg.user_id = uid then perform public.raise_user_error('O‘z xabaringizga shikoyat qilib bo‘lmaydi'); end if;
  insert into public.group_reports (message_id, reporter_id, reason) values (p_id, uid, left(p_reason, 100))
    on conflict (message_id, reporter_id) do update set reason = excluded.reason, created_at = now();
  select count(*) into cnt from public.group_reports
    where message_id = p_id and created_at > coalesce(msg.reports_reset_at, '-infinity'::timestamptz);
  update public.group_messages set report_count = cnt,
    hidden_at = case when cnt >= 3 and pinned_at is null then coalesce(hidden_at, now()) else hidden_at end
    where id = p_id;
  return jsonb_build_object('ok', true);
end $$;
