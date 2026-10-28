-- Signed-in API only
revoke execute on function public.ad_view(bigint), public.chat_list(), public.conversation_hide(bigint), public.conversation_read(bigint),
  public.conversation_start(bigint), public.dm_action(bigint, text, text), public.group_action(bigint, text, text, text),
  public.group_mark_read(text), public.group_me(), public.group_report(bigint, text),
  public.group_send(text, text, text, uuid, text, text, integer, bigint, integer, integer), public.group_state(text),
  public.is_participant(bigint)
  from public, anon;
grant execute on function public.ad_view(bigint), public.chat_list(), public.conversation_hide(bigint), public.conversation_read(bigint),
  public.conversation_start(bigint), public.dm_action(bigint, text, text), public.group_action(bigint, text, text, text),
  public.group_mark_read(text), public.group_me(), public.group_report(bigint, text),
  public.group_send(text, text, text, uuid, text, text, integer, bigint, integer, integer), public.group_state(text),
  public.is_participant(bigint)
  to authenticated;

-- Trigger bodies and internal helpers are never called through the API
revoke execute on function public.ads_before_write(), public.dm_after_insert(), public.dm_before_insert(),
  public.handle_new_user(), public.profiles_guard(), public.is_blocked_between(uuid, uuid)
  from public, anon, authenticated;

comment on view public.public_profiles is 'Intentionally SECURITY DEFINER: exposes only the public columns of profiles (phone only when phone_visible), so other members can be shown without opening the profiles table.';
