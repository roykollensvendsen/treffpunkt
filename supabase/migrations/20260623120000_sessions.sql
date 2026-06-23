-- Personal session sync (spec 0024 / ADR-0017).
--
-- One row per completed session, owned by the signed-in shooter. The primary
-- key is the client-generated UUID the app mints when recording starts, so a
-- re-upload is an idempotent upsert (no duplicate row). Queryable columns feed a
-- future result list; the full snapshot is kept loss-free in `payload` (jsonb).
--
-- Owner-only Row-Level Security: every policy is restricted to
-- `auth.uid() = user_id`, so a personal session is visible only to its owner. No
-- policy exposes another user's rows.
--
-- Apply with `supabase db push` or the SQL editor; this is NOT applied to any
-- hosted project automatically (ADR-0017).

create table public.sessions (
  id          uuid primary key,
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  program     text not null,
  captured_at timestamptz,
  place_label text,
  latitude    double precision,
  longitude   double precision,
  weapon_name text,
  total       int not null,
  max_total   int not null,
  inner_tens  int not null,
  payload     jsonb not null,
  created_at  timestamptz not null default now()
);

alter table public.sessions enable row level security;

-- A shooter may read only their own sessions.
create policy "Sessions are selectable by their owner"
  on public.sessions
  for select
  using (auth.uid() = user_id);

-- A shooter may insert only sessions owned by themselves; `with check` rejects a
-- row whose `user_id` is not the caller (it defaults to `auth.uid()`).
create policy "Sessions are insertable by their owner"
  on public.sessions
  for insert
  with check (auth.uid() = user_id);

-- A shooter may update only their own sessions, and only to a row that is still
-- their own (so the upsert overwrite stays owner-scoped).
create policy "Sessions are updatable by their owner"
  on public.sessions
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- A shooter may delete only their own sessions.
create policy "Sessions are deletable by their owner"
  on public.sessions
  for delete
  using (auth.uid() = user_id);

-- Grant the signed-in role table access (RLS still confines every request to
-- the owner via the policies above). Without this grant a hosted, RLS-enabled
-- table rejects every request with "permission denied", which the best-effort
-- repository swallows — so the upload would silently never work. `anon` is
-- intentionally NOT granted: only signed-in shooters upload their sessions.
grant select, insert, update, delete on public.sessions to authenticated;
