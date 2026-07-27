<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0162 — Tørrtrening-synk (dry-fire log across devices)

- **Status:** Draft
- **Related:** spec 0161 (the local dry-fire log — this is its deferred sync
  increment), spec 0083 (`felt_sessions` sync — the template this mirrors),
  ADR-0017 (client-generated ids; migrations applied by hand, not to hosted)

## Summary

Spec 0161 shipped the Tørrtrening card with a log kept on the device. This
increment makes that log **follow the shooter across devices**: each entry is
backed up to Supabase and entries recorded on one device appear on another. It
mirrors the ring- and felt-session sync exactly — an owner-scoped table, a
best-effort push, an owner-only pull — so it adds no new sync machinery, only a
new table and repository.

## Requirements

1. A signed-in shooter's dry-fire entries are uploaded to Supabase, idempotently
   (re-uploading the same entry never duplicates a row).
2. On load, a signed-in shooter's log is the union of the entries stored on the
   device and those in Supabase (so entries from another device show up).
3. Registering while signed in uploads the new entry; registering while signed
   out keeps it on the device, and signing in later backs it up.
4. Every row is visible and writable **only** to its owner (Row-Level Security).
5. A backend that is unreachable never breaks the card: it still shows the
   entries stored on the device.

## Rationale

- **Mirror `felt_sessions`.** The ring and felt features already sync one row
  per record, keyed by the client-generated id so a re-upload is an idempotent
  upsert, behind owner-only RLS. Copying that shape keeps the dry-fire sync
  boringly consistent and re-uses `guardSync` / the `SyncException` family.
- **The device stays the source of truth offline.** The local `DryFireStore`
  (spec 0161) is unchanged; sync is layered on top. The card reads local first
  so it is instant and works offline; the remote merge fills in cross-device
  entries when it arrives. A failed pull falls back to the local log, never an
  empty card (a missing table must not read as "no practice").
- **The whole entry is the row.** Unlike a session (queryable columns plus an
  opaque payload), a dry-fire entry is already just id + time + discipline +
  count, so every field is a real column — no `payload` blob, and the log can be
  aggregated server-side later (the statistics increment).
- **No auto-apply to hosted (ADR-0017).** The migration ships in the repo and is
  applied by hand, exactly like `felt_sessions`; until it is applied the card
  simply stays local (req 5), so shipping the code before the table is safe.

## Design

### Table — `supabase/migrations/…_dry_fire_entries.sql`

```
id            text primary key
user_id       uuid not null default auth.uid() references auth.users on delete cascade
recorded_at   timestamptz not null
discipline    text not null            -- the DryFireDiscipline wireName
trigger_pulls int  not null
created_at    timestamptz not null default now()
```

Owner-only RLS: select / insert / update / delete each restricted to
`auth.uid() = user_id`; `grant … to authenticated` only (never `anon`). A verbatim
copy of the `felt_sessions` policy set.

### Repository — `lib/features/scoring/data/dry_fire_repository.dart`

- `DryFireRepository` — `abstract interface`:
  - `Future<void> upload(List<DryFireEntry> entries)` — best-effort batch upsert
    (never throws), on conflict `id`.
  - `Future<List<DryFireEntry>> list()` — the owner's entries, newest first;
    throws `DryFireSyncException` (a `SyncException`) on failure.
- `InMemoryDryFireRepository` — the default binding and test fake.
- `SupabaseDryFireRepository` — `from('dry_fire_entries').upsert(rows,
  onConflict: 'id')` and `.select().order('recorded_at', ascending: false)`,
  wrapped in `guardSync`. The discipline column stores the `wireName`.

### Wiring — `DryFireLog` (spec 0161) gains sync

- `build()` loads the local log (fast, offline) and returns it immediately; if
  the shooter is signed in it kicks off a background `sync()` and also listens to
  `authStateChangesProvider`, running `sync()` on a transition into `SignedIn`.
- `register()` appends locally and persists as before, then best-effort uploads
  the single new entry.
- `sync()` (best-effort, guarded): batch-uploads every local entry (idempotent —
  this backs up anything logged while signed out), then `list()`s the remote
  entries, unions them with the local ones by `id`, persists the merged log and
  publishes it as state. A failed `list()` leaves the local state in place.
- `dryFireRepositoryProvider` defaults to the in-memory repository; `main()`
  overrides it with the Supabase one through `bootstrap.dart`, like
  `sessionRepositoryProvider`.

### Not in this increment

- The **statistics surface** (dry-fire volume over time on Statistikk) stays the
  next increment; the columns here are ready for a server-side aggregate.

## Verification

### Unit tests

- `dry_fire_repository_test`: the in-memory repository upserts by id
  (re-uploading the same id replaces, never duplicates) and lists what was
  uploaded.
- `dry_fire_log_sync_test`:
  - signed out, `register` touches the repository not at all and the entry is
    local only;
  - signed in, `register` uploads the new entry;
  - `sync` uploads all local entries and merges remote-only entries into the log
    (union by id, no duplicates), persisting the result;
  - a repository whose `list` throws leaves the local log intact (req 5).

### System / manual

- Applying the migration to a local Supabase, then recording on one signed-in
  client and seeing the entry appear on a second, signed in as the same user.
- RLS: a second user cannot read the first user's rows (owner-scoped policies).

## Open questions

- None. Cross-device *conflict* is a non-issue: entries are append-only and
  keyed by a unique client id, so a union by id is always correct.
