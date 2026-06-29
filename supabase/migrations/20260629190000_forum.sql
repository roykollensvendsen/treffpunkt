-- Community forum — bug reports & feature ideas (spec 0054).
--
-- A shared, app-wide forum: any signed-in user can start a thread (categorised
-- bug / idea / general), reply to threads, and read everything. An admin
-- (listed in app_admins) can moderate — delete anyone's thread or reply.
--
--   forum_threads  one row per thread: a category, a title and an opening body.
--   forum_posts    one row per reply to a thread.
--   app_admins     the moderators (managed by SQL/migration, not the client).
--
-- RLS:
--   read   — any authenticated user (a single shared community);
--   insert — only as yourself (author_id = auth.uid());
--   delete — the author, OR an admin (is_app_admin). No update (immutable).
--
-- Both content tables are added to the Realtime publication so the thread list
-- and a thread's replies update live.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

-- ---------------------------------------------------------------- app_admins --
create table public.app_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

-- A user may see whether they themselves are an admin (to show moderation
-- controls); the list is otherwise private and managed out-of-band.
create policy "Admins can read their own admin row"
  on public.app_admins for select
  to authenticated
  using (user_id = auth.uid());

grant select on public.app_admins to authenticated;

-- Whether a user is a moderator. SECURITY DEFINER + empty search_path, like the
-- competition helpers, so a policy that calls it reads RLS-bypassed.
create function public.is_app_admin(uid uuid)
  returns boolean
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select exists (
    select 1 from public.app_admins a where a.user_id = uid
  );
$$;

revoke all on function public.is_app_admin(uuid) from public;
grant execute on function public.is_app_admin(uuid) to authenticated;

-- Seed the initial moderator by email (the maintainer). A no-op if they have not
-- signed in yet; more admins are added with an INSERT here or in the SQL editor.
insert into public.app_admins (user_id)
  select id from auth.users
  where lower(email) = 'roykollensvendsen@gmail.com'
  on conflict (user_id) do nothing;

-- ------------------------------------------------------------- forum_threads --
create table public.forum_threads (
  id         uuid primary key,
  author_id  uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  category   text not null default 'general'
               check (category in ('bug', 'idea', 'general')),
  title      text not null,
  body       text not null default '',
  created_at timestamptz not null default now()
);

create index forum_threads_created_at_idx
  on public.forum_threads (created_at desc);

alter table public.forum_threads enable row level security;

create policy "Threads are readable by any authenticated user"
  on public.forum_threads for select to authenticated using (true);

create policy "Threads are insertable by their author"
  on public.forum_threads for insert to authenticated
  with check (auth.uid() = author_id);

create policy "Threads are deletable by the author or an admin"
  on public.forum_threads for delete to authenticated
  using (auth.uid() = author_id or public.is_app_admin(auth.uid()));

grant select, insert, delete on public.forum_threads to authenticated;

-- --------------------------------------------------------------- forum_posts --
create table public.forum_posts (
  id         uuid primary key,
  thread_id  uuid not null
               references public.forum_threads (id) on delete cascade,
  author_id  uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);

create index forum_posts_thread_id_created_at_idx
  on public.forum_posts (thread_id, created_at);

alter table public.forum_posts enable row level security;

create policy "Posts are readable by any authenticated user"
  on public.forum_posts for select to authenticated using (true);

create policy "Posts are insertable by their author"
  on public.forum_posts for insert to authenticated
  with check (auth.uid() = author_id);

create policy "Posts are deletable by the author or an admin"
  on public.forum_posts for delete to authenticated
  using (auth.uid() = author_id or public.is_app_admin(auth.uid()));

grant select, insert, delete on public.forum_posts to authenticated;

-- Live thread list + replies via Realtime; RLS still applies (everyone reads).
alter publication supabase_realtime add table public.forum_threads;
alter publication supabase_realtime add table public.forum_posts;
