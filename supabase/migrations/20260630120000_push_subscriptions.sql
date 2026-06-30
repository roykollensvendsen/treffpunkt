-- Web Push subscriptions (spec 0060).
--
-- One row per browser push subscription, owned by the user who created it.
-- Increment B's sender reads recipients' rows with the service role (which
-- bypasses RLS); clients are confined by RLS to their own rows.

create table public.push_subscriptions (
  endpoint   text primary key,
  user_id    uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  p256dh     text not null,
  auth       text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

create index push_subscriptions_user_id_idx
  on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

create policy "read own push subscriptions"
  on public.push_subscriptions for select
  using (user_id = auth.uid());

create policy "insert own push subscriptions"
  on public.push_subscriptions for insert
  with check (user_id = auth.uid());

create policy "update own push subscriptions"
  on public.push_subscriptions for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "delete own push subscriptions"
  on public.push_subscriptions for delete
  using (user_id = auth.uid());
