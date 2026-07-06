# ADR-0028: Generic upload-queue engine in lib/core/sync

- **Status:** Accepted
- **Date:** 2026-07-06

## Context
The offline-first upload machinery exists twice: the ring upload queue
(`UploadQueueNotifier`, spec 0025) and the felt sync notifier
(`FeltSyncNotifier`, spec 0083) each carry their own copy of the same
algorithm — a serial task chain so operations never interleave, a
signed-in gate, an upload-all/flush pass, an auth listener that flushes on
sign-in, and a competition-result submission fanned out from a successful
upload. Two copies of subtle async plumbing drift apart and must each be
reasoned about and tested on their own.

## Decision
`lib/core/sync/upload_queue_engine.dart` owns the offline-first upload
**algorithm** as one plain, pure-Dart class, `UploadQueueEngine<T>` — no
Flutter, no Riverpod, no `Ref`. Features **instantiate** it, injecting
their capabilities as constructor closures:

- `idOf` — the record's stable identity (the dedup and delete key),
- `load` / `persist` — the durable local store,
- `tryUpload` — one record's upload **including any fan-out** (e.g. the
  competition-result submission), returning whether everything succeeded,
- `isSignedIn` — the gate for every flush,
- `onState` — where to mirror the pending list (e.g. Riverpod state).

The engine keeps the queue semantics proven by specs 0025/0029/0033:
mutations run serially on one task chain (a failed predecessor is
swallowed so it cannot poison the chain, ADR-0013), the pending list
dedups by id (latest wins, an idempotent upsert), a record persists
*before* it uploads (so nothing is ever lost), and a failed upload keeps
the record queued for the next flush.

Per ADR-0027 this lands in two steps: the introduce-primitive PR adds the
engine with its own unit tests and rewires only the **ring** notifier —
strictly behavior-preserving, the existing upload-queue tests as the net.
Felt parity (moving `FeltSyncNotifier` onto the engine, which also gives
felt a durable pending queue) follows as its own spec'd PR.

## Consequences
- The trickiest async code in the app — the serial chain — is written,
  documented and tested exactly once.
- Feature notifiers shrink to thin shells: an auth listener, capability
  closures over their providers, and state mirroring.
- The engine is unit-tested as pure Dart with plain in-memory closures —
  no ProviderContainer needed.
- Felt sync can gain the ring queue's stronger guarantees (durable
  pending list, keep-on-failure) by adopting the engine.

## Alternatives considered
- **A Riverpod base notifier:** couples the algorithm to the framework
  and to one state shape; a pure class stays testable in isolation and
  reusable from any wrapper.
- **Rewiring ring and felt in one PR:** felt's adoption changes behavior
  (it currently has no durable queue), so it needs its own spec; mixing it
  into a behavior-preserving refactor would blur the net.
- **Leaving the duplication:** two copies of subtle async plumbing that
  drift, each needing its own review and tests.
