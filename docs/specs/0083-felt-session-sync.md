# Spec 0083 — Feltskyting: sync finished rounds to the account

- **Status:** Accepted.
- **Related:** 0082 (felt rounds in "Mine økter", local), 0024 (personal ring
  session sync, which this mirrors), 0025 (upload queue), ADR-0017.

## Context
Finished felt rounds are saved locally (spec 0082) but never leave the device,
so they don't follow the shooter across devices the way ring sessions do (spec
0024). This uploads a finished felt round to the shooter's Supabase account and
lists the account's felt rounds in "Mine økter", so a round recorded on one
device shows on another.

## Requirements
1. A finished felt round is **uploaded** to the account (owner-only), keyed by
   its stable id so a re-upload is an idempotent upsert.
2. Uploading is **best-effort and offline-tolerant**: a round is always kept
   locally (spec 0082); upload is attempted on finish, on sign-in, and at app
   start, and a failure just leaves the local copy to retry — never blocks
   recording.
3. Only **signed-in** shooters upload; a signed-out round stays local and shows
   in "Mine økter" until the next sign-in.
4. "Mine økter" shows the account's felt rounds (from the cloud) merged with the
   local ones by id, so a round from another device appears and a round present
   both places shows once.

## Rationale
**Mirror the ring session sync (spec 0024).** A `felt_sessions` table with
owner-only RLS (`auth.uid() = user_id`), a `FeltSessionRepository`
(`upload`/`list`, best-effort upload, `FeltSyncException` on a failed list) with
in-memory and Supabase implementations, and a kept-alive sync that flushes on
sign-in and at app start — the same shape and invariants as the ring upload
queue, so behaviour and tests are consistent.

**Keep the local history as the source; cloud is an enhancement.** Unlike the
ring pending queue (which empties on upload), the felt `FeltHistoryStore` (spec
0082) stays the permanent local history, so a round is never lost offline. Sync
idempotently pushes local rounds to the cloud; "Mine økter" merges cloud + local
by id (cloud wins the tiebreak). The full round is kept loss-free in the row's
`payload`; queryable columns (`captured_at`, `group_name`, `points`) feed the
list.

**Graceful until the table exists.** Like the ring table, the migration is not
applied to hosted Supabase automatically (ADR-0017); until the maintainer runs
`supabase db push`, the best-effort upload logs and swallows and the list is
treated as a non-blocking failure (spec 0029) — the local rounds still show.

## Design
- `supabase/migrations/<ts>_felt_sessions.sql`: the `felt_sessions` table +
  owner-only RLS + grant to `authenticated`.
- `felt_session_repository.dart` (data): `FeltSessionRepository` interface,
  `InMemoryFeltSessionRepository`, `FeltSyncException`.
- `supabase_felt_session_repository.dart` (data):
  `SupabaseFeltSessionRepository` (upsert on `id`; `list()` orders by
  `captured_at` desc; rebuilds each record from `payload`).
- `felt_providers.dart`: `feltSessionRepositoryProvider`,
  `feltSyncedSessionsProvider` (FutureProvider → `list()`), and
  `feltSyncProvider` (a kept-alive notifier: uploads all local rounds on sign-in
  and at start; `uploadOne` on finish).
- `felt_record_screen.dart`: on finish, after saving locally, `uploadOne`.
- `app.dart`: watch `feltSyncProvider` to keep it alive (like the upload queue).
- `my_sessions_screen.dart` / `my_sessions_providers.dart`: merge the synced +
  local felt rounds by id before building the unified list; the picker
  invalidates the felt providers when opening the list.
- `bootstrap.dart` / `main.dart`: wire `SupabaseFeltSessionRepository`.

## Verification
- **Unit** (`felt_session_repository_test.dart`): the in-memory repository is
  idempotent by id and lists what was uploaded.
- **Unit** (`my_sessions_providers_test.dart`): merging local + synced felt
  rounds deduplicates by id.
- **Provider** (`felt_sync_test.dart`): finishing a round signed in uploads it
  once; signed out uploads nothing and keeps it local; signing in flushes the
  local rounds; a throwing repository never breaks finishing.
- **Widget**: a felt round that exists only in the cloud shows in "Mine økter".

## Out of scope
- Deleting a synced felt round; editing a round.
- Felt rounds as competition results.
- Applying the migration to hosted Supabase (a manual maintainer step).
