# Spec 0024 — Personal session sync

- **Status:** Accepted
- **Related:** ADR-0017 (personal session sync), ADR-0013 (offline-first
  recording and sync), spec 0009 (offline session persistence), spec 0003
  (Google sign-in), ADR-0010 (secrets/config), ADR-0012 (session domain model)

## Context

A signed-in shooter records sessions offline (spec 0009). A completed session is
saved only on the device, and the local store is cleared on completion (spec
0009 req 4), so the result is lost on a reinstall or a move to another device,
and nothing yet feeds the result lists ADR-0013 anticipates.

This spec lays the **foundation** for "your sessions follow your account": when a
session completes and the user is signed in, upload it to Supabase under that
user. The upload is **best-effort** (it never blocks recording or crashes the
app) and **idempotent** (a retry never creates a duplicate), per ADR-0017. The
real Supabase access lives in one file, excluded from automated tests and
verified manually, exactly like `SupabaseAuthRepository` (spec 0003), so no test
ever touches a real backend.

## Requirements

1. **Stable session id.** Every recording carries a client-generated UUID `id`,
   stable for the session's life. It is generated when recording starts (an
   injected generator, so tests are deterministic), serialized in the
   `SessionSnapshot` and round-tripped through the local store, so a recording
   resumed after a restart (spec 0009) keeps the **same** id. The domain stays
   pure: the id is supplied to the value types, never generated inside them. The
   addition is compatible — existing `Session.start` / snapshot tests are
   unchanged (the id defaults when absent).
2. **`SessionRecord` — the uploadable form.** A pure-Dart value type holding a
   completed session's `id`, `program` name, optional `capturedAt`, optional
   place (`label` / `lat` / `lng`), optional `weaponName`, the rolled-up `total`
   / `maxTotal` / `innerTens`, and the full `SessionSnapshot.toJson()` map as
   `payload`. It is built losslessly from a completed `Session` and its
   `SessionScore`.
3. **`SessionRepository` seam.** A data-layer interface with
   `Future<void> upload(SessionRecord)`. `InMemorySessionRepository` is the
   default binding and the test fake: it records uploaded records and is
   idempotent by `id` (a second upload of the same id keeps one). A
   `sessionRepositoryProvider` exposes it; tests and the integration harness use
   the in-memory default and never reach Supabase.
4. **`SupabaseSessionRepository`** is the **only** new file importing
   `supabase_flutter`. It `upsert`s the record into the `sessions` table keyed by
   `id` (so a re-upload is idempotent) and lets the database default
   `user_id = auth.uid()`. It is **best-effort: it catches every error and never
   throws**, logging via `debugPrint` guarded by `!kReleaseMode`, so a missing
   table or a dropped connection never crashes the app. It is excluded from
   automated tests and verified manually (like spec 0003).
5. **Auto-upload on completion, signed-in only.** When a recording becomes
   complete and the user is signed in, its `SessionRecord` is uploaded exactly
   once, fire-and-forget — never blocking the UI, best-effort (a throwing
   repository does not break completion), idempotent via `id`. A signed-out
   completion uploads nothing. Completion still reaches the scorecard either way.
6. **Owner-only storage.** The `public.sessions` table has `user_id` defaulting
   to `auth.uid()` and Row-Level Security with owner-only policies — every
   `select` / `insert` / `update` / `delete` restricted to `auth.uid() =
   user_id`. No policy exposes another user's rows.
7. **Config and purity.** No secret is committed (ADR-0010). The domain and
   presentation layers import no `supabase_flutter`; only
   `SupabaseSessionRepository` does. New Dart files carry the SPDX header and
   doc comments and pass `very_good_analysis` (strict). Existing tests stay
   green.

## Rationale

The id must be **client-generated and stable** (ADR-0013) so the upsert is
idempotent and an offline client can name the row it will upload. It rides on the
`SessionRecording` / `SessionSnapshot` (not on the pure `Session`, which models
the scoring aggregate) so the many `Session.start` and snapshot tests are
untouched and the domain stays pure — the id is generated in the presentation
notifier from an injected generator and serialized in the snapshot, so a resume
(spec 0009) restores the same id.

`SessionRecord` separates the **uploadable** view of a session from the in-memory
recording: queryable columns for a future result list, plus the loss-free
`payload` (the spec 0009 snapshot JSON, re-scorable against current tables). It
is pure Dart so the mapping is a fast unit test.

The repository seam mirrors `AuthRepository` / `SessionStore`: the app depends on
an interface, the fake makes upload-on-complete unit-testable with no I/O, and
`SupabaseSessionRepository` confines plugin imports to one manually-verified file
(spec 0003). Upload is **best-effort and never throws** for the same reason the
local autosave is (spec 0009): losing one upload is not fatal — the local
recording is authoritative this run — but a crash would be, so the Supabase repo
swallows and logs instead of propagating, and the table not yet existing in
hosted Supabase cannot break the deployed app.

## Design

```
lib/features/scoring/
  domain/
    session_record.dart     SessionRecord value type (id, program, capturedAt?,
                            placeLabel?/latitude?/longitude?, weaponName?,
                            total, maxTotal, innerTens, payload) +
                            SessionRecord.fromSession(session, score, id:).
    session_snapshot.dart   + optional `id` carried through toJson/fromJson
                            (defaults when absent, so old records still load).
  data/
    session_repository.dart SessionRepository interface (upload);
                            InMemorySessionRepository (default + fake, idempotent
                            by id).
    supabase_session_repository.dart   the ONLY new plugin-importing file:
                            best-effort upsert into `sessions` keyed by id.
  presentation/
    session_providers.dart  + sessionIdGeneratorProvider (default const Uuid().v4);
                            SessionRecording carries `id`; SessionNotifier.build
                            mints an id (or keeps the restored one) and uploads
                            the SessionRecord on completion when signed in;
                            sessionRepositoryProvider (InMemory default).
lib/bootstrap.dart          runTreffpunkt gains an optional SessionRepository.
lib/main.dart               passes SupabaseSessionRepository(Supabase...client).
supabase/migrations/<ts>_sessions.sql   create public.sessions + RLS policies.
```

`sessions` row: `id uuid primary key`, `user_id uuid not null default auth.uid()
references auth.users(id) on delete cascade`, `program text not null`,
`captured_at timestamptz`, `place_label text`, `latitude double precision`,
`longitude double precision`, `weapon_name text`, `total int not null`,
`max_total int not null`, `inner_tens int not null`, `payload jsonb not null`,
`created_at timestamptz not null default now()`. RLS enabled; owner-only
`select` / `insert` (`with check`) / `update` (`using` + `with check`) / `delete`
all on `auth.uid() = user_id`.

The id is serialized as `"id"` in the snapshot JSON; a record written before this
change has no `id`, so `fromJson` defaults it (the recording then mints a fresh
one). On resume the stored id flows back through `SessionRecording`, so the
resumed session uploads under the same id and the upsert overwrites in place.

## Verification

### Unit tests

- `session_record_test`: `SessionRecord.fromSession(session, score, id: ...)`
  maps a completed multi-stage session to the queryable columns — `program`
  name, `capturedAt`, `placeLabel` / `latitude` / `longitude` from the metadata,
  `weaponName` from the weapon, and `total` / `maxTotal` / `innerTens` from the
  `SessionScore` — and its `payload` equals `SessionSnapshot(session: session)`'s
  `toJson()` (round-trips back to an equal snapshot); a session with no metadata
  and no weapon maps those fields to `null`.
- `session_snapshot_test` (extended): the `id` round-trips through
  `toJson` / `fromJson` when present and defaults (a non-null fresh value, or a
  documented sentinel) when the JSON omits it, so an old stored record still
  loads; all existing snapshot round-trips stay green.
- `session_repository_test`: `InMemorySessionRepository` records an uploaded
  record and exposes it by id; a second `upload` of a record with the **same id**
  keeps exactly one (idempotent); two different ids keep two.

### Widget / provider tests

- `session_sync_test` (ProviderContainer, fake repo + fake auth):
  - completing a session **while signed in** uploads exactly one `SessionRecord`
    with the recording's id and the correct `total` / `innerTens`;
  - the id is **stable across resume**: a recording restored from a snapshot
    keeps the snapshot's id, and the uploaded record carries that same id;
  - completing **while signed out** uploads nothing;
  - completing twice with the same id (e.g. a resumed-then-completed session)
    leaves the fake holding exactly one record (idempotent);
  - a repository whose `upload` **throws** does not break completion — the
    notifier still reaches the complete state and no error propagates
    (best-effort swallow).

### System tests

- `place_shot_test` / `auth_flow_test` keep passing unchanged: the wiring adds an
  in-memory `SessionRepository` by default, so the signed-in flow still reaches
  the scorecard and a centre shot still scores a ten; no test reaches Supabase.

### Manual (maintainer, once credentials + the table exist)

- Apply `supabase/migrations/<ts>_sessions.sql` to the hosted project
  (`supabase db push` or the SQL editor).
- After applying the migration, verify a signed-in upsert actually **inserts a
  row** (not merely that the table exists): the migration grants the
  `authenticated` role table access, and without that grant an RLS-enabled table
  rejects every upsert with "permission denied" — which the best-effort
  repository swallows, so a missing grant would silently never store anything.
- Sign in, complete a session, confirm one row appears under the signed-in
  `user_id` with the right columns and `payload`; complete the same resumed
  session again and confirm the row is overwritten, not duplicated.
- Confirm a second account cannot see the first account's rows (RLS).

## Known limitations (this is the foundation)

- **No retry / no queue yet.** If the user is offline (or signed out) at
  completion, the session is **not** uploaded, and — per spec 0009 — the local
  store is still cleared on completion, so the session is **not** retried later.
  A pending-upload queue, a local "My sessions" history and the list screen are
  the **next** increment.
- **No list / read-back screen yet.** This spec only writes rows; reading them
  back into the app is a later increment.
- The migration is **not** applied to any hosted project here; the maintainer
  applies it to turn uploads on (ADR-0017). Until then the best-effort repository
  logs and returns, and the app is unharmed.

## Open questions

- Where the pending-upload queue lives (extend `SessionStore`, or a dedicated
  outbox) and its retry/backoff policy (ADR-0013) — the next increment.
- Whether completed sessions are kept locally as a history rather than cleared on
  completion (spec 0009 req 4) once the queue exists.
- A CI/architecture check forbidding `supabase` imports outside the two data
  files (mirrors the spec 0003 open question).
