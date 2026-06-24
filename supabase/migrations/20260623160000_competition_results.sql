-- Competition results & shared scoreboards — schema + RLS (spec 0012).
--
-- One row per submitted result, keyed by the SESSION id (the same client-
-- generated uuid the shooter minted when recording started). Keying on the
-- session id makes a re-submit a no-op: the durable upload queue can retry and
-- never creates a duplicate (the client submits ON CONFLICT DO NOTHING).
--
-- RLS:
--   read   — anyone who can read the competition (the scoreboard);
--   insert — only your OWN result, and only for a competition you participate
--            in. There is deliberately NO update policy: results are immutable
--            once submitted, so the idempotent submit is a pure INSERT and can
--            never trip an UPDATE WITH CHECK (the createCompetition lesson — an
--            ON CONFLICT DO UPDATE would, but DO NOTHING does not).
--   delete — your own result (so a shooter may retract).
--
-- The read/insert checks call the SECURITY DEFINER helpers from
-- 20260623140000_competitions.sql (can_read_competition /
-- is_competition_participant), which read RLS-bypassed and return a boolean, so
-- no policy re-enters the competitions / competition_members policies.
--
-- The result's `program` is carried for display and re-scoring; it is NOT
-- checked against the competition's program at the database level — the
-- "Skyt nå" flow launches the competition's fixed program, so a mismatch cannot
-- arise from the app. (Revisit with a SECURITY DEFINER program helper if a
-- free-pick submission path is ever added.)
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create table public.competition_results (
  id             uuid primary key,
  competition_id uuid not null
                   references public.competitions (id) on delete cascade,
  user_id        uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  program        text not null,
  total          int not null,
  max_total      int not null,
  inner_tens     int not null,
  captured_at    timestamptz,
  payload        jsonb not null,
  created_at     timestamptz not null default now()
);

create index competition_results_competition_id_idx
  on public.competition_results (competition_id);

alter table public.competition_results enable row level security;

-- Read: the scoreboard — anyone who can read the competition.
create policy "Results are readable by anyone who can read the competition"
  on public.competition_results for select
  to authenticated
  using (public.can_read_competition(competition_id, auth.uid()));

-- Insert: only your own result, and only for a competition you participate in.
create policy "Results are insertable by a participant for themselves"
  on public.competition_results for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.is_competition_participant(competition_id, auth.uid())
  );

-- Delete: a shooter may retract their own result.
create policy "Results are deletable by their owner"
  on public.competition_results for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.competition_results to authenticated;
