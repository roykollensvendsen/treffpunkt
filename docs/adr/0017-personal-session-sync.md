# ADR-0017: Personal session sync to the shooter's account

- **Status:** Accepted
- **Date:** 2026-06-23

## Context
A signed-in shooter records sessions offline (ADR-0013, spec 0009). Today a
completed session lives only in the local store, which is cleared on completion
(spec 0009), so it does not survive a reinstall or a move to another device, and
nothing yet feeds the result lists ADR-0013 anticipates. The first step toward
"your sessions follow your account" is to save each completed session to
Supabase under the signed-in user — best-effort and idempotent, so it never
blocks recording and a retry never duplicates a row.

This is the foundation. A pending-upload queue (for sessions completed offline
or signed out), a local "My sessions" history and the list screen are the next
increment, not this one.

## Decision
- **One row per completed session, keyed by a client-generated id.** Each
  recording is given a stable UUID `id` (ADR-0013 already calls for a
  client-generated id) the moment it starts, carried through the local snapshot
  so a resumed session keeps the same id. The id is the primary key of a
  `public.sessions` row, so re-uploading the same session is an idempotent
  **upsert** that overwrites in place rather than inserting a duplicate.
- **Queryable columns plus a full snapshot.** The row stores the columns a
  future result list will filter and sort on — `program`, `captured_at`,
  `place_label` / `latitude` / `longitude`, `weapon_name`, and the rolled-up
  `total` / `max_total` / `inner_tens` — alongside the complete
  `SessionSnapshot.toJson()` map as a `jsonb payload`. The payload is the
  loss-free source of truth (it can be re-scored against the current tables, as
  in spec 0009); the columns exist only so the database can answer list queries
  without unpacking JSON.
- **Owner-only Row-Level Security.** `user_id` defaults to `auth.uid()` and every
  policy (`select` / `insert` / `update` / `delete`) is restricted to
  `auth.uid() = user_id`. No policy exposes another user's rows; a personal
  session is visible only to its owner. Cross-user result lists are a later,
  explicitly-shared surface, not this table.
- **A repository seam, the real backend in one excluded file.** The app depends
  on a pure `SessionRepository` interface (`upload(SessionRecord)`).
  `InMemorySessionRepository` is the default binding and the test fake.
  `SupabaseSessionRepository` is the **only** new file importing
  `supabase_flutter`; like `SupabaseAuthRepository` (spec 0003) it is excluded
  from automated tests and verified manually, so no test ever reaches a real
  Supabase.
- **Upload is best-effort and never throws.** The Supabase repository catches
  every error and swallows it (logging via `debugPrint` guarded by
  `!kReleaseMode`, matching the best-effort local persistence in spec 0009), so a
  missing table or a dropped connection cannot crash the app or break the
  completion flow. Completion always reaches the scorecard.
- **Signed-in only, fire-and-forget.** The auto-upload runs only when the user is
  signed in and never blocks the UI; a signed-out completion uploads nothing.
- **The migration is applied by the maintainer.** The `sessions` table and its
  policies ship as a SQL migration in `supabase/migrations/`. It is **not**
  applied to any hosted project here; the maintainer runs it (e.g.
  `supabase db push` or the SQL editor) to turn uploads on. Until then the
  best-effort repository simply logs and returns, so the app is unharmed.

## Consequences
- A signed-in shooter's completed sessions survive a reinstall or device change
  once the migration is applied; until then nothing breaks.
- Retries and a future pending-upload queue are safe by construction: the upsert
  by client-generated id is idempotent.
- The queryable columns let a later result-list screen sort and filter in the
  database without parsing `payload`, while `payload` keeps the upload lossless.
- There are two stores until upload: the local store is authoritative on the
  range, the server after a successful upload (ADR-0013).
- The purity boundary holds: the domain and presentation layers import no
  `supabase_flutter`; only `SupabaseSessionRepository` does, and it is untested
  automatically and manually verified.

## Alternatives considered
- **A database-generated id (e.g. `gen_random_uuid()`):** rejected — a retry
  could not be made idempotent without first reading the server, and an offline
  client could not name the row it is about to upload. A client-generated id
  makes the upsert trivially idempotent (ADR-0013).
- **Only a `jsonb` blob, no columns:** rejected — a result list would have to
  unpack JSON for every sort/filter. Promoting the few list-facing fields to
  columns keeps queries cheap while `payload` stays the loss-free record.
- **Uploading inside `SupabaseAuthRepository` or a generic data service:**
  rejected — it would blur the auth seam and spread plugin imports. A dedicated
  `SessionRepository` mirrors the established one-file-per-backend pattern.
- **Blocking the scorecard on a successful upload:** rejected — it would fail the
  offline-first requirement (ADR-0013); upload is fire-and-forget and the local
  recording is authoritative this run.
