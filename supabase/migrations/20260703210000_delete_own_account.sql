-- Slett din egen profil (spec 0126): a SECURITY DEFINER RPC that deletes the
-- caller's auth user; every user-owned table references auth.users with
-- on delete cascade, so this erases the profile, synced sessions/felt
-- rounds, owned competitions (members' results included), memberships,
-- messages, results, forum threads/posts, reactions, notifications, push
-- subscriptions and training samples in one statement. The client can
-- delete exactly one account: its own.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
