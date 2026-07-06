<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0144 — Durabel opplastingskø for felt-runder

- **Status:** Accepted
- **Related:** spec 0025 (ring durable queue), 0082/0083 (felt local + sync),
  0089 (delete a felt round), 0140 (felt competitions), ADR-0028 (engine)

## Context

The felt sync has drifted from the ring queue it was cloned from. Today
`FeltSyncNotifier` re-uploads the **entire local history** on every start and
sign-in, has no durable notion of what is actually pending, and — the real
defect — only the finish-moment `uploadOne` submits a competition result
(spec 0140): a competition round finished **offline** is uploaded by the later
`uploadAll`, but its result is **never submitted to the scoreboard**. The ring
side already solved all of this with a durable pending queue (spec 0025), now
extracted as the shared `UploadQueueEngine` (ADR-0028). Felt gets the same.

## Requirements

1. A finished felt round is **enqueued** in a durable pending store
   (`felt_pending_uploads` via the shared prefs JSON-list store) the moment it
   is saved to history — before any upload attempt, so it survives an app
   death or an offline session.
2. The queue **flushes** on app start, on sign-in and after every enqueue:
   each pending round is uploaded AND — for a competition round — its result
   submitted (spec 0140), the round leaving the queue only when **everything**
   succeeded. Failures keep the round queued for the next flush; signed-out
   flushes are no-ops.
3. Deleting a felt round (spec 0089) also **removes it from the pending
   queue** (`deleteById`), so a deleted round can never upload afterwards.
4. The sync is an instance of the shared `UploadQueueEngine` (ADR-0028) — the
   same serial-chain, dedup-by-id, persist-before-upload semantics as the ring
   queue; `feltSyncProvider`'s state becomes the pending `List<FeltSessionRecord>`.
5. The whole-history re-upload on start/sign-in is **retired**. Already-synced
   rounds are not re-uploaded; rounds finished before this version (not in any
   queue) are covered by the one-time migration: an existing local history
   with no pending store yet seeds an empty queue (they were already uploaded
   by the old reconcile, or will sync on next finish — no data loss, no
   re-upload storm).

## Rationale

- **Fixes the offline competition-result gap** by construction: enqueue/flush
  runs the same `tryUpload` closure (upload + submit) no matter when the
  upload finally happens — the finish-moment and the reconcile can no longer
  behave differently.
- **Engine reuse over parallel code**: the drift happened precisely because
  felt re-implemented the queue by hand; instantiating the shared engine makes
  the semantics tested once and shared (ADR-0028).
- **Retiring the re-upload** cuts server traffic from O(history) to
  O(pending) per start.

## Design

- `FeltPendingUploadsStore` (interface + `InMemory` + `SharedPreferences`
  via `PrefsJsonListStore<FeltSessionRecord>`, key `felt_pending_uploads`,
  malformed → empty), provider-wired like the ring's pending store.
- `FeltSyncNotifier extends Notifier<List<FeltSessionRecord>>` becomes a thin
  shell over `UploadQueueEngine<FeltSessionRecord>`: auth `ref.listen` →
  `flush()`, `start()` at build, capabilities = load/persist on the pending
  store, `tryUpload` = repository upload + `_submitResult` fan-out (upload and
  submit best-effort, return false on any failure), `isSignedIn` from
  `authStateChangesProvider`, `onState` → Riverpod state.
- `saveFeltRound` enqueues; `deleteFeltRound` calls the queue's `deleteById`
  in addition to today's history/server deletes.
- `uploadAll`/`uploadOne` disappear; callers move to `enqueue`/`flush`.

## Verification

### Unit tests

- Engine capabilities: `tryUpload` returns false when the repository upload
  or the competition-result submit throws; true only when both succeed
  (competition round) / upload succeeds (training round).

### System tests (widget)

- A round finished while signed out is queued (pending state non-empty,
  store persisted) and NOT uploaded; on sign-in it uploads AND its
  competition result is submitted — the offline-competition defect's
  regression test.
- A round finished signed-in uploads immediately and leaves the queue.
- A failing repository keeps the round queued; a later flush retries.
- The queue (with a pending round) survives a provider-container restart
  (simulated app restart): the round loads from the store and uploads.
- Deleting a pending round removes it from the queue and the store; it never
  uploads.
- Start/sign-in does NOT re-upload rounds that are only in history (no
  pending entry).

## Open questions

- None. Deletion-sync of already-uploaded rounds while offline (ring parity:
  direct best-effort call) is unchanged and out of scope.
