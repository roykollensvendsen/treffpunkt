-- Per-user competition archive (spec 0049).
--
-- Lets a user hide a competition from their own active list without deleting it
-- — the answer for competitions created by SOMEONE ELSE, which a non-owner
-- cannot delete (spec 0034). Archiving is purely personal view state: one row
-- per (competition, user) that the user has archived. It never changes
-- membership, results or what any other participant sees.
--
-- RLS is trivial — a user reads, sets and clears ONLY their own rows
-- (auth.uid() = user_id) — so no SECURITY DEFINER helper and no policy
-- recursion (nothing else's policy consults this table). The insert check also
-- requires the caller can actually read the competition, reusing the existing
-- can_read_competition helper, so no junk rows for invisible competitions.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create table public.competition_archives (
  competition_id uuid not null
                   references public.competitions (id) on delete cascade,
  user_id        uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  archived_at    timestamptz not null default now(),
  primary key (competition_id, user_id)
);

alter table public.competition_archives enable row level security;

-- A user sees only their own archive rows.
create policy "Archives are readable by their owner"
  on public.competition_archives for select
  to authenticated
  using (auth.uid() = user_id);

-- A user archives only for themselves, and only a competition they can read.
create policy "Archives are insertable by their owner"
  on public.competition_archives for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_read_competition(competition_id, auth.uid())
  );

-- A user restores (un-archives) only their own row.
create policy "Archives are deletable by their owner"
  on public.competition_archives for delete
  to authenticated
  using (auth.uid() = user_id);

-- RLS confines every request to the policies above; `anon` is granted nothing.
grant select, insert, delete on public.competition_archives to authenticated;
