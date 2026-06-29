-- Optional event date for a competition (spec 0057).
--
-- The date the competition is held, set by the owner when creating it. It lets
-- the competitions list be browsed/filtered by a calendar (pappa's wish). It is
-- nullable — a competition without a date simply has none — and does not affect
-- any policy.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

alter table public.competitions add column event_date date;
