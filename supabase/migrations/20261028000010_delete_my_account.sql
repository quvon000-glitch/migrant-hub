-- NOT YET APPLIED (needs owner confirmation in Supabase)
-- Account removal by its owner: auth user row cascades to the profile and all content
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then perform public.raise_user_error('Avval hisobga kiring'); end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
