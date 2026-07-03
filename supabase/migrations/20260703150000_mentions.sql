-- @-tagging i meldinger (spec 0120): a `@[Navn]` marker in a forum post, a
-- thread body or a competition message notifies the named account with a
-- `mention` row, and the generic fan-outs skip mentioned users so one
-- message never notifies twice. Names resolve case-insensitively against
-- profiles.display_name at insert time; unresolved names (Robot Hood
-- included — the robot has no profile row) simply fan out to nobody.

alter table public.notifications
  drop constraint notifications_kind_check;
alter table public.notifications
  add constraint notifications_kind_check
    check (kind in ('invitation', 'competition_message', 'forum_reply',
                    'mention'));

-- The accounts named by @[...] markers in a body.
create or replace function public.mention_user_ids(p_body text)
returns setof uuid
language sql
stable
set search_path = ''
as $$
  select p.id from public.profiles p
  where lower(p.display_name) in (
    select lower(m[1])
      from regexp_matches(p_body, '@\[([^\]]+)\]', 'g') m
  );
$$;

-- ---------------------------------------------------------------- forum ----
create or replace function public.notify_forum_mentions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title  text;
  v_sender text;
begin
  select t.title into v_title from public.forum_threads t
    where t.id = new.thread_id;
  select p.display_name into v_sender from public.profiles p
    where p.id = new.author_id;
  insert into public.notifications
      (user_id, kind, title, body, thread_id)
    select u, 'mention',
           coalesce(v_sender, 'Noen') || ' nevnte deg: '
             || coalesce(v_title, 'tråd'),
           left(new.body, 140), new.thread_id
      from public.mention_user_ids(new.body) u
      where u <> new.author_id;
  return null;
end;
$$;

create trigger forum_posts_mentions
  after insert on public.forum_posts
  for each row execute function public.notify_forum_mentions();

-- A thread's opening body can mention too.
create or replace function public.notify_thread_mentions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender text;
begin
  select p.display_name into v_sender from public.profiles p
    where p.id = new.author_id;
  insert into public.notifications
      (user_id, kind, title, body, thread_id)
    select u, 'mention',
           coalesce(v_sender, 'Noen') || ' nevnte deg: ' || new.title,
           left(new.body, 140), new.id
      from public.mention_user_ids(new.body) u
      where u <> new.author_id;
  return null;
end;
$$;

create trigger forum_threads_mentions
  after insert on public.forum_threads
  for each row execute function public.notify_thread_mentions();

-- The generic reply fan-out (spec 0094) skips mentioned users: the mention
-- row, which names the recipient, wins.
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
      where r.user_id <> new.author_id
        and r.user_id not in (select public.mention_user_ids(new.body));
  return null;
end;
$$;

-- --------------------------------------------------------- competitions ----
create or replace function public.notify_message_mentions()
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
    select u, 'mention',
           coalesce(v_sender, 'Noen') || ' nevnte deg i '
             || coalesce(v_name, 'konkurransen'),
           left(new.body, 140), new.competition_id
      from public.mention_user_ids(new.body) u
      where u <> new.user_id;
  return null;
end;
$$;

create trigger competition_messages_mentions
  after insert on public.competition_messages
  for each row execute function public.notify_message_mentions();

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
      where r.user_id <> new.user_id
        and r.user_id not in (select public.mention_user_ids(new.body));
  return null;
end;
$$;
