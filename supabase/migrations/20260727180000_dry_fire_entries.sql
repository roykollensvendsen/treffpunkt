-- Dry-fire log sync (spec 0162 / ADR-0017).
--
-- One row per recorded dry-fire bout, owned by the signed-in shooter. The
-- primary key is the client-generated id the app mints when the bout is
-- registered, so a re-upload is an idempotent upsert (no duplicate row). Every
-- field of the entry is a real column — a dry-fire entry has no opaque payload —
-- so the log can be aggregated server-side later (the statistics increment).
-- Mirrors the ring `sessions` and `felt_sessions` tables.
--
-- Owner-only Row-Level Security: every policy is restricted to
-- `auth.uid() = user_id`, so an entry is visible only to its owner. No policy
-- exposes another user's rows.
--
-- Apply with `supabase db push` or the SQL editor; this is NOT applied to any
-- hosted project automatically (ADR-0017).

create table public.dry_fire_entries (
  id            text primary key,
  user_id       uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  recorded_at   timestamptz not null,
  discipline    text not null,
  trigger_pulls int not null,
  created_at    timestamptz not null default now()
);

alter table public.dry_fire_entries enable row level security;

-- A shooter may read only their own entries.
create policy "Dry-fire entries are selectable by their owner"
  on public.dry_fire_entries
  for select
  using (auth.uid() = user_id);

-- A shooter may insert only entries owned by themselves; `with check` rejects a
-- row whose `user_id` is not the caller (it defaults to `auth.uid()`).
create policy "Dry-fire entries are insertable by their owner"
  on public.dry_fire_entries
  for insert
  with check (auth.uid() = user_id);

-- A shooter may update only their own entries, and only to a row that is still
-- their own (so the upsert overwrite stays owner-scoped).
create policy "Dry-fire entries are updatable by their owner"
  on public.dry_fire_entries
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- A shooter may delete only their own entries.
create policy "Dry-fire entries are deletable by their owner"
  on public.dry_fire_entries
  for delete
  using (auth.uid() = user_id);

-- Grant the signed-in role table access (RLS still confines every request to
-- the owner via the policies above). `anon` is intentionally NOT granted: only
-- signed-in shooters sync their entries.
grant select, insert, update, delete on public.dry_fire_entries to authenticated;
