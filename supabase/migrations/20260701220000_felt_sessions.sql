-- Feltskyting round sync (spec 0083 / ADR-0017).
--
-- One row per finished felt round, owned by the signed-in shooter. The primary
-- key is the client-generated id the app mints when the round finishes, so a
-- re-upload is an idempotent upsert (no duplicate row). Queryable columns feed
-- the "Mine økter" list; the full round is kept loss-free in `payload` (jsonb,
-- the FeltSessionSnapshot). Mirrors the ring `sessions` table.
--
-- Owner-only Row-Level Security: every policy is restricted to
-- `auth.uid() = user_id`, so a round is visible only to its owner. No policy
-- exposes another user's rows.
--
-- Apply with `supabase db push` or the SQL editor; this is NOT applied to any
-- hosted project automatically (ADR-0017).

create table public.felt_sessions (
  id          text primary key,
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  captured_at timestamptz,
  group_name  text not null,
  points      int not null,
  payload     jsonb not null,
  created_at  timestamptz not null default now()
);

alter table public.felt_sessions enable row level security;

-- A shooter may read only their own rounds.
create policy "Felt rounds are selectable by their owner"
  on public.felt_sessions
  for select
  using (auth.uid() = user_id);

-- A shooter may insert only rounds owned by themselves; `with check` rejects a
-- row whose `user_id` is not the caller (it defaults to `auth.uid()`).
create policy "Felt rounds are insertable by their owner"
  on public.felt_sessions
  for insert
  with check (auth.uid() = user_id);

-- A shooter may update only their own rounds, and only to a row that is still
-- their own (so the upsert overwrite stays owner-scoped).
create policy "Felt rounds are updatable by their owner"
  on public.felt_sessions
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- A shooter may delete only their own rounds.
create policy "Felt rounds are deletable by their owner"
  on public.felt_sessions
  for delete
  using (auth.uid() = user_id);

-- Grant the signed-in role table access (RLS still confines every request to
-- the owner via the policies above). `anon` is intentionally NOT granted: only
-- signed-in shooters sync their rounds.
grant select, insert, update, delete on public.felt_sessions to authenticated;
