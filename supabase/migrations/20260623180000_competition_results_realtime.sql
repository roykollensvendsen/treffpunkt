-- Live competition scoreboard via Supabase Realtime (spec 0013).
--
-- Add competition_results to the supabase_realtime publication so a subscriber
-- receives Postgres change events for it (the scoreboard updates the instant a
-- participant submits). Supabase does NOT add tables to this publication
-- automatically, so it must be done here.
--
-- Row-Level Security still applies to Realtime: a subscriber only receives
-- changes to rows its SELECT policy (`can_read_competition`) lets it read, so a
-- non-member — or a change in a competition they cannot see — is never
-- delivered. No new policy is needed.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

alter publication supabase_realtime add table public.competition_results;
