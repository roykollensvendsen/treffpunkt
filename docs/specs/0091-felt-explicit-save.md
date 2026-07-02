# Spec 0091 — Felt: save the finished round with a button, exactly once

- **Status:** Accepted
- **Related:** spec 0080 (recording), 0081 (save/resume), 0082 (rounds in
  Mine økter — the auto-save-on-finish part is superseded), 0083 (sync)

## Context

Finishing a felt round auto-saved it to history — and minted a **new id on
every finish**. The scorecard's back button returns to the recording, so
walking back and forth (Fullfør → tilbake → Fullfør …) saved the same round
several times. The domain expert hit exactly this: *"jeg gikk litt opp og
ned og fikk plutselig flere økter lagret etterhverandre"* — and asks for the
round to be saved **with a button** when done.

The ring flow does not have this defect: its completion enqueue is
idempotent by the recording's stable id (spec 0025). This spec brings felt
to parity and makes the save deliberate.

## Requirements

1. **Fullfør** shows the scorecard **without saving** the round.
2. The recorder's scorecard carries a **«Lagre økt»** button. Pressing it
   saves the round to history and uploads it (best-effort, spec 0083)
   **exactly once**: repeated presses, or repeated Fullfør → tilbake →
   Fullfør round-trips, never produce more than one saved record.
3. Until the round is saved, it stays **in progress**: leaving the recorder
   keeps the «Fortsett felt-økt» card (spec 0081), so an unsaved finished
   round is never lost. Saving clears the in-progress store.
4. After saving, the recorder closes back to the course page and confirms
   with «Økta er lagret». The saved round shows in Mine økter as before.
5. The read-only scorecard opened from Mine økter shows **no** save button.

## Rationale

The explicit button is what the domain expert asked for, and it makes the
moment of record-creation visible. The duplicate defect is still fixed one
level deeper, so no navigation path can recreate it: the round's **id is
minted once** when the recorder opens (not per finish), and the history
save **upserts by id** (replaces a same-id record instead of prepending a
copy) — the felt counterpart of the ring queue's dedup-by-id.

Keeping an unsaved finished round in the in-progress store (req 3) is what
makes "no auto-save" safe: the only ways out of an unfinished-to-saved round
are the save button, the discard action (spec 0081) and starting over —
never silent loss.

## Design

- `_FeltRecordScreenState` mints `_roundId` once in `initState`; `_finish()`
  only flips to the scorecard view. A new `_save()` builds the record with
  `_roundId`, awaits the history save, fires the sync upload, clears the
  in-progress store, shows the snackbar and pops.
- `_persist()` no longer clears the store on finish — only an empty round
  (or the save/discard actions) clears it.
- `saveFeltRound` (spec 0082) upserts by id: the new record replaces any
  stored record with the same id.
- The button lives in the recorder's scorecard `Scaffold`, not in the shared
  `FeltScorecard` body — the Mine økter detail view is untouched (req 5).

## Verification

### Unit tests
- `felt_in_my_sessions_test`: `saveFeltRound` called twice with the same id
  keeps one record (upsert).

### System tests
- `felt_record_screen_test` / `felt_in_my_sessions_test`:
  - Fullfør alone saves nothing; tapping **Lagre økt** saves the round;
  - the regression: Fullfør → tilbake → Fullfør → Lagre økt →
    **exactly one** record in history;
  - after saving, the recorder pops and «Økta er lagret» shows.
- `felt_session_persistence_test`: a finished-but-unsaved round still
  resumes from the «Fortsett felt-økt» card; **saving** clears the store.
- The Mine økter detail scorecard shows no «Lagre økt» button.

## Open questions
- None.
