-- «Jobber med» (spec 0117): a thread status for work in progress — set when
-- implementation starts, moved to done when the fix is deployed. Same
-- moderation rules as spec 0066.

alter table public.forum_threads
  drop constraint forum_threads_status_check;
alter table public.forum_threads
  add constraint forum_threads_status_check
    check (status in ('open', 'planned', 'in_progress', 'done', 'rejected'));

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
  if p_status not in ('open', 'planned', 'in_progress', 'done', 'rejected') then
    raise exception 'invalid status';
  end if;
  update public.forum_threads set status = p_status where id = p_thread_id;
end;
$$;

revoke all on function public.set_thread_status(uuid, text) from public, anon;
grant execute on function public.set_thread_status(uuid, text) to authenticated;
