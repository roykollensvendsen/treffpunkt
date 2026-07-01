# Spec 0081 — Feltskyting: save & resume a session

- **Status:** Accepted.
- **Related:** 0080 (felt hit recording), 0009 (offline ring-session
  persistence, which this mirrors), ADR-0016 (local storage).

## Context
A felt round (spec 0080) lives only in the recording screen's memory, so
leaving the screen or restarting the app loses it. The ring sessions already
survive a restart and offer a **"Fortsett økt"** card (spec 0009,
`SessionStore` over `shared_preferences`). This gives felt the same: an
in-progress round is saved as you place shots and can be **resumed** from the
course preview.

## Requirements
1. While recording, the in-progress round is **saved** after every change — the
   shooter's group, the shots placed on each hold (position + which figure and
   inner zone they hit), and which hold is current.
2. The saved round **survives an app restart** (persisted via
   `shared_preferences`).
3. The course preview shows a **"Fortsett felt-økt"** card when a saved round
   exists; tapping it **resumes** exactly where the shooter left off (group,
   every placed shot, current hold). The card can be **discarded**.
4. **Finishing** the round (reaching the scorecard) clears the saved round, and
   a round with no shots is not saved — so the card only offers a real,
   in-progress round.

## Rationale
**Mirror the ring `SessionStore`.** The same interface + in-memory/shared-prefs
implementations, so felt is testable without real I/O and consistent with the
ring feature. A `FeltSessionStore` persists one active round under its own key
`active_felt_session`.

**A pure-Dart snapshot; positions are stored.** `FeltSessionSnapshot`
(Flutter-free domain) serializes the group, the per-hold `FeltPlacedShot`s
(each: position `dx`/`dy` in hold pixel space, the hit `figureIndex` — null for
a miss — and `inner`) and the current hold. Positions are stored so the resume
redraws the markers exactly where they were placed; the resolved figure/inner
are stored too, so the score is restored without re-running the hit-test.

**Local recording state, provider-injected store.** The recorder keeps its own
`setState` state (spec 0080); only the store is injected via a Riverpod
provider, so the course preview can watch it for the resume card — the lighter
wiring the felt feature already uses, not the ring's full notifier.

## Design
- `felt_session_snapshot.dart` (domain): `FeltPlacedShot` and
  `FeltSessionSnapshot` with `toJson`/`fromJson`.
- `felt_session_store.dart` (data): `FeltSessionStore` interface,
  `InMemoryFeltSessionStore`, `SharedPreferencesFeltSessionStore` (key
  `active_felt_session`).
- `felt_providers.dart` (presentation): `feltSessionStoreProvider` (in-memory
  default) and `feltSavedSessionProvider` (FutureProvider reading the store).
- `felt_record_screen.dart`: a `ConsumerStatefulWidget` that persists after each
  change (saving when any shot is placed, clearing when empty or finished) and
  seeds itself from an optional `restored` snapshot.
- `felt_course_screen.dart`: a `ConsumerWidget` that shows the "Fortsett
  felt-økt" card (with a discard button) when a saved round exists and resumes
  into the recorder.
- `bootstrap.dart` / `main.dart`: wire `SharedPreferencesFeltSessionStore`,
  like the ring `SessionStore`.

## Verification
- **Unit** (`felt_session_snapshot_test.dart`): a snapshot round-trips through
  `jsonEncode`/`jsonDecode` — group, per-hold shots including a miss
  (`figureIndex == null`) and an inner hit, and the current hold.
- **Unit** (`felt_session_store_test.dart`): in-memory and shared-prefs stores
  save, load an equal snapshot, and clear it; load is null before any save.
- **Widget** (`felt_session_persistence_test.dart`): placing a shot saves the
  round; a saved round is restored on a fresh mount (markers and score back);
  finishing clears the store; the course preview shows the resume card for a
  saved round, resumes it, and discards it.

## Out of scope
- Uploading/syncing finished felt rounds and a "Mine økter" list (later, like
  the ring sessions — spec 0024/0026).
- Session metadata (weapon, place, time) on a felt round.
