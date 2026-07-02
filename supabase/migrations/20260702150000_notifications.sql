-- In-app notifications (spec 0094): one row per recipient, written by
-- database triggers, read/marked by the owner. This table is also the event
-- source the spec-0060 push function can read, so in-app and OS delivery
-- share one pipeline.

-- ---------------------------------------------------------- notifications --
create table public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  kind           text not null
                   check (kind in ('invitation', 'competition_message',
                                   'forum_reply')),
  title          text not null,
  body           text not null default '',
  competition_id uuid null references public.competitions (id)
                   on delete cascade,
  thread_id      uuid null references public.forum_threads (id)
                   on delete cascade,
  created_at     timestamptz not null default now(),
  read_at        timestamptz null
);

create index notifications_user_id_created_at_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

-- Recipients see and mark (update read_at on) their own rows; inserts happen
-- only inside the security-definer trigger functions below.
create policy "Notifications are readable by their recipient"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

create policy "Notifications are markable by their recipient"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, update on public.notifications to authenticated;

-- Live badge updates (the app subscribes per recipient).
alter table public.notifications replica identity full;
alter publication supabase_realtime add table public.notifications;

-- ------------------------------------------------------------- fan-out ----
-- An invitation notifies the invitee (when their email maps to an account).
create or replace function public.notify_invitation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.user_id_for_email(new.invited_email);
  v_name text;
begin
  if v_user is null then
    return null;
  end if;
  select c.name into v_name from public.competitions c
    where c.id = new.competition_id;
  insert into public.notifications
      (user_id, kind, title, body, competition_id)
    values
      (v_user, 'invitation', 'Invitasjon: ' || coalesce(v_name, 'konkurranse'),
       'Du er invitert til å bli med.', new.competition_id);
  return null;
end;
$$;

create trigger competition_invitations_fanout
  after insert on public.competition_invitations
  for each row execute function public.notify_invitation();

-- A chat message notifies every member (and the owner) except the sender.
create or replace function public.notify_competition_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name   text;
  v_sender text;
begin
  select c.name into v_name from public.competitions c
    where c.id = new.competition_id;
  select p.display_name into v_sender from public.profiles p
    where p.id = new.user_id;
  insert into public.notifications
      (user_id, kind, title, body, competition_id)
    select r.user_id, 'competition_message',
           coalesce(v_sender, 'Ny melding') || ' i '
             || coalesce(v_name, 'konkurransen'),
           left(new.body, 140), new.competition_id
      from (
        select m.user_id from public.competition_members m
          where m.competition_id = new.competition_id
        union
        select c.owner_id from public.competitions c
          where c.id = new.competition_id
      ) r
      where r.user_id <> new.user_id;
  return null;
end;
$$;

create trigger competition_messages_fanout
  after insert on public.competition_messages
  for each row execute function public.notify_competition_message();

-- A forum reply notifies the thread's earlier participants (the thread
-- author and everyone who posted), except the reply's author.
create or replace function public.notify_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
begin
  select t.title into v_title from public.forum_threads t
    where t.id = new.thread_id;
  insert into public.notifications
      (user_id, kind, title, body, thread_id)
    select r.user_id, 'forum_reply',
           'Nytt svar: ' || coalesce(v_title, 'tråd'),
           left(new.body, 140), new.thread_id
      from (
        select t.author_id as user_id from public.forum_threads t
          where t.id = new.thread_id
        union
        select p.author_id from public.forum_posts p
          where p.thread_id = new.thread_id
      ) r
      where r.user_id <> new.author_id;
  return null;
end;
$$;

create trigger forum_posts_fanout
  after insert on public.forum_posts
  for each row execute function public.notify_forum_reply();
