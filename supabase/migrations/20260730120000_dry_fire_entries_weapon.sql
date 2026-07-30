-- Dry-fire weapon type (spec 0165).
--
-- Records which pistol type a bout was practised with — Luftpistol, Finpistol
-- or Grovpistol — as a stable wireName. NULLABLE: entries recorded before this
-- feature have no weapon, and a pre-feature row read back yields null. No
-- default, no back-fill.
--
-- The column inherits the table's owner-only Row-Level Security (the policies
-- from 20260727180000_dry_fire_entries.sql are row-scoped, not column-scoped),
-- so no policy or grant change is needed. `if not exists` keeps the manual
-- hosted re-apply idempotent (ADR-0017 — this is NOT applied automatically).
--
-- ROLLOUT ORDER: apply this to the hosted project BEFORE deploying the
-- weapon-aware client. The client's upsert sends a `weapon` key; against a table
-- without the column PostgREST rejects the whole batch, and the best-effort
-- upload swallows it — so new bouts would silently fail to back up until the
-- column exists (local logging is unaffected and a later sync back-fills).

alter table public.dry_fire_entries
  add column if not exists weapon text;
