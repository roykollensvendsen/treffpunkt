# Spec 0082 — Feltskyting: finished rounds in "Mine økter"

- **Status:** Accepted. The save-on-finish behaviour is superseded by spec
  0091: the round is saved with the scorecard's explicit «Lagre økt» button.
- **Related:** 0080 (felt recording), 0081 (felt save/resume), 0026 ("Mine
  økter" list), 0025 (local completed-session store). Local-first; cloud sync is
  a later step.

## Context
A finished felt round (spec 0080) is not kept anywhere — on **Fullfør** the
in-progress round (spec 0081) is cleared and the result is gone. Ring sessions,
in contrast, land in **"Mine økter"**. This stores a finished felt round
**locally** and shows it in the **same "Mine økter" list** alongside the ring
sessions, so all results live in one place.

## Requirements
1. Finishing a felt round (reaching the scorecard, with at least one shot) saves
   it **locally** with its date, group and per-hold result.
2. Saved felt rounds appear in **"Mine økter"**, interleaved with ring sessions
   by date, each row showing it is a felt round with its **total points**.
3. Tapping a felt row opens its **scorecard** (per-hold treff/figur/inner and the
   total).
4. Saved felt rounds **survive an app restart** (`shared_preferences`).

## Rationale
**Local-first, mirroring the ring store.** A `FeltHistoryStore` (in-memory +
shared-prefs, key `felt_session_history`) keeps the list of finished rounds, like
the ring `PendingUploadsStore` (spec 0025) — but with no upload queue yet, since
felt cloud sync is out of scope here. A `FeltSessionRecord` (id, `capturedAt`,
and the round's `FeltSessionSnapshot`) is the stored value; the score is computed
from the snapshot via `FeltSessionTally`, so there is one source of truth.

**One list, a small union — private internals only.** The list stays keyed by
date across both kinds. `MySessionEntry` (ring) and the felt record are wrapped
in a sealed `MySessionItem`; the list/calendar dispatch on it to render a ring
`_SessionCard` or a felt card. `MySessionEntry`, `mergeMySessions` and the row
widgets are unchanged for ring sessions, so nothing about the ring path (or its
tests) changes — felt is purely additive. The scoring feature depends on the
felt feature (one direction; felt imports nothing from scoring).

**Reused scorecard.** The felt scorecard is extracted into a public
`FeltScorecard`, used both at the end of recording and from the list detail.

## Design
- `felt_session_record.dart` (domain): `FeltSessionRecord` (id, capturedAt,
  `FeltSessionSnapshot`) with `toJson`/`fromJson` and a `tally` getter.
- `felt_history_store.dart` (data): `FeltHistoryStore` interface,
  in-memory + `shared_preferences` implementations.
- `felt_providers.dart`: `feltHistoryStoreProvider`, `feltHistoryProvider`
  (FutureProvider), and `saveFeltRound` to append + invalidate.
- `felt_record_screen.dart`: on finish, save a `FeltSessionRecord` to history
  (once, if any shots); render the extracted `FeltScorecard`.
- `felt_scorecard.dart` (presentation): `FeltScorecard` body widget;
  `felt_session_detail_screen.dart`: `FeltSessionDetailScreen` wraps it.
- `my_sessions_providers.dart`: `sealed MySessionItem`
  (`RingSessionItem`/`FeltSessionItem`) + `mergeSessionItems` (by date, newest
  first).
- `my_sessions_screen.dart`: also watch `feltHistoryProvider`, build the unified
  item list, and dispatch each row (ring card or felt card → detail).
- `bootstrap.dart` / `main.dart`: wire `SharedPreferencesFeltHistoryStore`.

## Verification
- **Unit** (`felt_session_record_test.dart`): a record round-trips through JSON
  (id, capturedAt, snapshot) and its `tally`/points match the snapshot.
- **Unit** (`felt_history_store_test.dart`): in-memory and shared-prefs stores
  save/load/clear a list of records.
- **Unit** (`my_sessions_providers_test.dart`): `mergeSessionItems` interleaves
  ring and felt items newest-first, undated last.
- **Widget** (`felt_session_persistence_test.dart` / a my-sessions test):
  finishing a felt round adds it to the history; "Mine økter" shows a felt row
  with its points among ring sessions; tapping it opens the felt scorecard.

## Out of scope
- Uploading/syncing felt rounds to Supabase and cross-device history.
- Editing or deleting a saved felt round.
- Weapon/place metadata on a felt round.
