-- A lifecycle status on forum threads, set by moderators (spec 0066).
--
-- A bug/idea moves open -> planned -> done / rejected. Only an app admin may
-- change it, through a SECURITY DEFINER RPC that updates *only* the status
-- column — so the moderation surface stays status + delete, never editing
-- someone else's content (spec 0063).

alter table public.forum_threads
  add column status text not null default 'open'
    check (status in ('open', 'planned', 'done', 'rejected'));

create or replace function public.set_thread_status(
  p_thread_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_app_admin(auth.uid()) then
    raise exception 'not authorized';
  end if;
  if p_status not in ('open', 'planned', 'done', 'rejected') then
    raise exception 'invalid status';
  end if;
  update public.forum_threads set status = p_status where id = p_thread_id;
end;
$$;

revoke all on function public.set_thread_status(uuid, text) from public, anon;
grant execute on function public.set_thread_status(uuid, text) to authenticated;
