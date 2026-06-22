# ADR-0013: Offline-first session recording with deferred sync

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
Shooters are often at ranges with poor or no connectivity, yet must be able to
record a full session — program, series, every shot and score, the weapon, the
time and the place — without a network. Results should upload to the competition
afterwards, and all participants then see the result list. Browsing competitions
and leaderboards may require a network.

## Decision
- **Recording is offline-first.** A session (the ADR-0012 aggregate) is created,
  edited and completed entirely on-device, persisted to local storage, and never
  blocks on the network.
- **Results sync as a deferred, idempotent upload.** Completed sessions are
  queued and pushed to Supabase when connectivity returns. Each session carries a
  stable **client-generated id** (ADR-0012), so retries never create duplicates.
  Once uploaded a session is **locked locally** (no edit-after-upload) and treated
  as immutable.
- **Upload reconciliation.** A session may carry an optional competition
  reference (ADR-0012). Uploading to a competition validates that the session's
  program / target-set matches the competition's. A **transient** failure (no
  signal, server busy) retries with backoff; a **permanent** rejection (e.g.
  program mismatch) moves the session to a *needs-attention* state instead of
  retrying forever, so the queue cannot spin.
- **Storage sits behind a repository interface** in the data layer (like
  `AuthRepository`), so the domain and presentation layers depend on an
  abstraction and the feature is testable without a real database or network. The
  concrete engine (e.g. Drift/SQLite, Hive, or files) is chosen in the
  persistence spec; the interface is what the rest of the app sees.

Reading competitions and scoreboards stays **online for now**; caching them for
full offline reading is a later option, not part of this decision.

## Consequences
- The app is usable on the firing line with no signal; nothing is lost if upload
  is delayed.
- Sync needs idempotency and a simple conflict rule (a completed, uploaded
  session is immutable); both are designed in the sync spec.
- There are two stores until upload: the local store is authoritative until a
  session is synced, the server after.
- Tests use a fake/in-memory store; the real store is integration-tested.

## Alternatives considered
- **Online-only with a local draft cache:** rejected — it fails the core "record
  without nett on the range" requirement.
- **Full offline replication of competitions and leaderboards now:** deferred —
  a heavier sync/conflict model than the first delivery needs; offline recording
  plus deferred upload already covers the stated need.
