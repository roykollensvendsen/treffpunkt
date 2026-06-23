# Spec 0025 — Upload queue for completed sessions

- **Status:** Accepted
- **Related:** spec 0024 (personal session sync), ADR-0017 (personal session
  sync), ADR-0013 (offline-first recording and deferred sync), spec 0009
  (offline session persistence), spec 0003 (Google sign-in)

## Context

Spec 0024 uploads a completed session to the shooter's account, but only
best-effort **at the moment it completes** and **only when signed in and
online**. If the shooter is offline or signed out when the session finishes,
nothing is uploaded — and per spec 0009 (req 4) the local store is cleared on
completion, so the result is simply **lost**: there is no retry and no place it
waits. Spec 0024 itself flagged this as the next increment ("No retry / no queue
yet … the session is not retried later").

This spec closes that gap with a durable **upload queue**. A completed session is
**enqueued locally** the instant it finishes — surviving an app restart — and
the queue is **flushed** (each pending session uploaded, then removed) whenever
that becomes possible: on completion, on app start, and when the user signs in.
No completed session is ever lost; a session finished offline or signed out
uploads itself automatically later.

## Requirements

1. **`SessionRecord` is serializable.** `SessionRecord` (spec 0024) gains
   `toJson()` and `SessionRecord.fromJson` that round-trip losslessly — `id`,
   `program`, optional `capturedAt`, optional `placeLabel` / `latitude` /
   `longitude`, optional `weaponName`, `total`, `maxTotal`, `innerTens` and the
   `payload` map — so a pending record can be persisted as JSON and read back
   identical. A record with all optional fields absent round-trips with those
   fields `null`.
2. **A pending-uploads store.** A data-layer `PendingUploadsStore` interface —
   `Future<List<SessionRecord>> load()` and `Future<void> save(List)` —
   mirroring `SessionStore` (spec 0009). `InMemoryPendingUploadsStore` is the
   default binding and the test fake; `SharedPreferencesPendingUploadsStore`
   persists the whole list as one JSON array under one key (ADR-0016). An empty
   or absent store loads to an empty list. Tests drive the prefs implementation
   with `SharedPreferences.setMockInitialValues`, so no real storage is touched.
3. **The queue.** An `UploadQueueNotifier` behind `uploadQueueProvider` owns the
   pending records, loaded from the `PendingUploadsStore` and **deduplicated by
   `id`** (enqueuing the same id twice keeps one — the latest wins, an
   idempotent upsert like the repository).
   - `enqueue(record)`: add or replace by id, persist the list, then `flush()`.
   - `flush()`: if **not** signed in, return — the records stay queued, unchanged.
     Otherwise, for each pending record, attempt
     `sessionRepositoryProvider.upload(record)`; on success drop it, on failure
     keep it; persist whatever remains. Fully **best-effort**: a throwing
     repository never escapes (the record stays safe in the queue) and never
     blocks the UI.
4. **Flush triggers.** The queue flushes on **app start** (when it initialises)
   and whenever auth **transitions to `SignedIn`** (it listens to
   `authStateChangesProvider`). It must not loop unboundedly: a single pass over
   the pending list per flush, no self-re-triggering.
   - **Eager initialisation (no-loss-on-restart).** Because both triggers run
     inside the notifier's `build`, the queue must be **built eagerly at app
     start and stay alive for the whole app session** — it cannot wait for a
     session completion to be its first reader. The always-mounted app root
     (`TreffpunktApp`) `ref.watch`es `uploadQueueProvider` (a plain,
     non-`autoDispose` `NotifierProvider`, so it is never torn down), purely to
     keep it built; it never reads the value. Without this, a session finished
     offline last run would never load or flush after a plain restart (no new
     completion), and a sign-in transition while the user is merely browsing
     would not flush — the data-loss this spec exists to prevent.
5. **Completion enqueues, never uploads directly.** `SessionNotifier.advance()`,
   when the session completes, **enqueues** the completed `SessionRecord` onto
   the queue (fire-and-forget, best-effort) instead of uploading it directly.
   The queue is now the durable home of completed sessions. The spec 0009
   clear-on-complete of the *active-session* store is unchanged — the active
   store holds the in-progress recording; the queue holds finished ones.
6. **No loss, ever.** Because a completed session is persisted in the queue
   before any upload is attempted, and a failed or signed-out upload leaves it
   in the queue, a completed session cannot be lost — it survives a restart and
   uploads on the next flush. Completion still reaches the scorecard in every
   case (signed in, signed out, offline, throwing repository).
7. **Wiring and purity.** `runTreffpunkt` gains an optional
   `PendingUploadsStore` that overrides its provider; omitting it keeps the
   in-memory default, so tests and the integration harness never touch real
   storage. `main()` passes `SharedPreferencesPendingUploadsStore(prefs)`. The
   domain and presentation layers import no `supabase_flutter`; new Dart files
   carry the SPDX header and doc comments and pass `very_good_analysis` (strict).
   Existing tests stay green.

## Rationale

The queue lives **outside** the active-session store (spec 0009) deliberately:
the active store models the *single in-progress recording* and is cleared on
completion, while the queue is an **outbox** of *finished* records waiting to
upload. Mixing the two would either resurrect a completed session as "resume me"
or lose it on the spec 0009 clear. A dedicated store keeps each concern's
lifecycle clean — and ADR-0013 / spec 0024 already named a dedicated outbox as
the expected home.

**Dedup by id** keeps the upsert semantics of the whole pipeline: the record's
`id` is the stable client-generated upload key (ADR-0017), so the queue keying on
it means a session enqueued twice (e.g. a resumed-then-re-completed session, or a
completion that also fires on a later start) is one row, and a flush is an
idempotent upsert end to end.

**Best-effort flush** mirrors the local autosave (spec 0009) and the Supabase
repository (spec 0024): losing one upload attempt is not fatal because the record
stays queued, but a thrown error escaping the UI would be — so the flush catches
everything, keeps the record on failure, and never propagates. **Persist before
upload** is what guarantees no-loss: the record is durable the instant it is
enqueued, so even a crash mid-upload leaves it queued for next time.

**The triggers** are exactly the moments an upload becomes newly possible:
completion (a new record arrives), app start (a record may be waiting from last
run), and a sign-in transition (a queued-while-signed-out record can now go up).
Listening to the auth status via `ref.listen` and firing a single flush pass
avoids a re-subscribe loop; each `flush` is one pass over the list with no
self-re-trigger, so the queue cannot spin (ADR-0013).

## Design

```
lib/features/scoring/
  domain/
    session_record.dart        + toJson() / SessionRecord.fromJson (lossless
                               round-trip of all fields incl. the payload map).
  data/
    pending_uploads_store.dart PendingUploadsStore interface (load/save list);
                               InMemoryPendingUploadsStore (default + fake);
                               SharedPreferencesPendingUploadsStore (one JSON
                               array under one key, ADR-0016).
  presentation/
    session_providers.dart     + pendingUploadsStoreProvider (in-memory default);
                               + uploadQueueProvider (UploadQueueNotifier);
                               SessionNotifier.advance enqueues the completed
                               record instead of uploading it directly.
    upload_queue.dart          UploadQueueNotifier: owns the pending records,
                               enqueue() (dedup-by-id, persist, flush),
                               flush() (signed-in only, per-record best-effort
                               upload+remove, persist remainder); flushes on
                               build (app start) and on a SignedIn transition.
lib/bootstrap.dart             runTreffpunkt gains an optional
                               PendingUploadsStore (overrides its provider).
lib/main.dart                  passes SharedPreferencesPendingUploadsStore(prefs).
```

The pending list is serialized as a JSON array of `SessionRecord.toJson()` maps
under one prefs key. On load the array is decoded back to records and
deduplicated by id (so a corrupt double-write self-heals). `enqueue` upserts by
id then flushes; `flush` no-ops when signed out and otherwise uploads each
record, dropping the ones that succeed and persisting the remainder.

The `UploadQueueNotifier` builds by loading the store (deduplicated) and kicking
off an initial flush (app start), and registers a `ref.listen` on
`authStateChangesProvider` that flushes once on a transition into `SignedIn`.
Both are fire-and-forget against the same single-pass `flush`, so there is no
recursion and no unbounded loop.

## Verification

### Unit tests

- `session_record_test` (extended): `toJson` / `fromJson` round-trips a full
  record (every field set, including a nested `payload` map) back to an equal
  record, and a minimal record (all optionals `null`) round-trips with those
  fields `null`.
- `pending_uploads_store_test`: for **both** implementations — an empty/absent
  store loads to an empty list; `save` then `load` round-trips a list of records
  (ids, totals and payload preserved); saving an empty list clears it. The
  prefs implementation is driven by `setMockInitialValues`.

### Provider tests

- `upload_queue_test` (ProviderContainer, fake repo + fake auth + in-memory
  pending store):
  - completing a session **while signed in** enqueues then uploads it; the
    queue ends **empty** and the repository holds the record with its id/score;
  - completing **while signed out** enqueues it and it **stays queued** (the
    repository got nothing, the record is not lost), and the pending store holds
    it;
  - then **signing in** flushes the queue: the record uploads (the repository
    now holds it) and the queue empties;
  - a repository whose `upload` **throws** leaves the record **queued** (no loss)
    and does not break completion (no error escapes);
  - enqueuing the **same id twice** keeps exactly **one** pending record;
  - **on app start**, a queue built over a pending store already holding records
    flushes them when signed in (the repository ends holding them, the queue
    empties);
  - **overlap on the serial chain** (a repository whose `upload` parks on a
    `Completer`): with A's flush in flight, enqueuing B then releasing the gate
    uploads A **exactly once** and B **exactly once** — no duplicate A, no
    dropped B — and the queue empties (pins the no-interleave/no-double-upload
    guarantee, by id);
  - **partial-failure flush** (a repository that accepts id `ok` and throws for
    id `bad`): the first flush uploads only `ok`, leaving the queue and pending
    store holding only `bad` (asserted by id); after `bad` starts succeeding a
    second flush drains it;
  - **dedup tiebreak**: a pending store pre-seeded (via `save`) with two records
    sharing an id loads to **one** record carrying the **last** id's data.
  All assert the records' ids/scores, not merely counts.

### Widget tests (eager-init / no-loss-on-restart)

- `upload_queue_app_test` mounts the **real app tree** (`TreffpunktApp` under a
  `ProviderScope`, the overrides `runTreffpunkt` applies) and relies on the
  app's own eager wiring — it never reads `uploadQueueProvider` directly:
  - **on app start, signed in**, a pending store pre-seeded with a completed
    record uploads it (the repository receives it) with **no new session
    completed**;
  - **signed out** the pre-seeded record stays queued (nothing uploads), then an
    emitted `SignedIn` transition — while the user is merely on the sign-in
    screen — flushes it (the sign-in listener, registered eagerly, fires).
  These fail before `TreffpunktApp` watches the queue (nothing else builds it
  without a completion) and pass after.

### System tests

- `place_shot_test` / `auth_flow_test` keep passing unchanged: the wiring adds an
  in-memory `PendingUploadsStore` by default, so completion still reaches the
  scorecard and no test touches real storage or Supabase.

## Open questions

- Backoff / retry pacing for a flush that keeps failing (ADR-0013 names backoff;
  this spec retries on the natural triggers only, no timer yet).
- A "My sessions" history read back from the server, and surfacing a
  pending/uploaded indicator in the UI — later increments.
- Whether a permanently-rejected record (a future competition mismatch, ADR-0013)
  moves to a *needs-attention* state rather than retrying forever — out of scope
  until competition identity exists (spec 0012).
