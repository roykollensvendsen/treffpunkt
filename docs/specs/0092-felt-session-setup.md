# Spec 0092 — Felt: time, place and weapon for NorgesFelt rounds

- **Status:** Accepted
- **Related:** spec 0008 (session metadata — the setup step), 0007 (weapons),
  0076 (place from location), 0080/0081 (felt recording, save/resume), 0083
  (felt sync), 0090 (statistics — uses the captured date)

## Context

Ring sessions start with a setup step: date and time (default now), a place
(typed or from device location) and the weapon. NorgesFelt rounds jump
straight to the group picker and only get a save-time timestamp. The domain
expert wants the same for felt — *"konsistent over hele fjøla"*.

## Requirements

1. **Skyt løypa** opens the **same setup step** the ring programs use — date
   and time (editable, defaults to now), place (typed or "Bruk min posisjon",
   spec 0076) and weapon — before the group picker.
2. The weapon choices are the shooter's **pistol** weapons (no class
   restriction — the course groups imply the weapon type), with the same
   "add weapon" flow as the ring setup.
3. The chosen date/time, place and weapon are **carried by the round**: they
   survive save/resume of an in-progress round (spec 0081), are stored with
   the finished record, and sync in the payload (spec 0083) with no schema
   change. The record's `capturedAt` is the **chosen** date, so Mine økter
   ordering and the statistics x-axis (spec 0090) use it.
4. A felt round already stored without the new fields still loads (additive
   JSON, nulls).
5. **Mine økter** shows the round's place and weapon on the felt card and in
   the detail view, in the same style as the ring cards.
6. The setup form is **one shared widget**: the ring flow and the felt flow
   render the identical form (same keys, texts and behaviours), each wrapped
   with its own title and confirm destination.

## Rationale

Consistency by construction: rather than copying the setup screen, its form
is extracted (`SessionSetupForm`) and both flows compose it — future setup
changes (e.g. a new field) reach both automatically. The `WeaponPicker` is
generalised the same way: it filters by discipline + class labels, with the
program constructor mapping onto that, so felt can say "pistol, any class"
without inventing a fake program.

## Design

- `WeaponPicker` gains a `WeaponPicker.forClasses({discipline, classLabels})`
  constructor; the existing `WeaponPicker(program:)` maps to it. An empty
  `classLabels` means every class of the discipline.
- `SessionSetupForm` (extracted from `SessionSetupScreen`): date/time, place
  + location, weapon section and the confirm button, reporting
  `onConfirm(SessionMetadata, Weapon?)`. `SessionSetupScreen` becomes the
  ring wrapper (program title → `SeriesScreen`); a new `FeltSetupScreen` is
  the felt wrapper (course title → `FeltRecordScreen`).
- `FeltSessionSnapshot` gains optional `capturedAt`, `placeLabel`,
  `latitude`, `longitude`, `weaponName` (flat, like `SessionRecord`) —
  additive JSON.
- `FeltRecordScreen` takes optional `metadata`/`weapon` from the setup (or
  from the restored snapshot) and writes them into every persisted snapshot
  and the saved record; `FeltSessionRecord.capturedAt` = the chosen date
  (fallback: save time).
- The felt card and `FeltSessionDetailScreen` render the place and weapon
  like the ring card does.

## Verification

### Unit tests
- `felt_session_snapshot_test`: metadata fields round-trip through JSON; a
  pre-0092 JSON (no fields) parses with nulls.

### System tests
- Felt flow: Skyt løypa → the setup form (same `dateTimeKey` /
  `placeFieldKey` / `sessionConfirmKey` the ring tests use) → group picker →
  record a shot → save; the saved record carries the typed place, the picked
  weapon and the chosen date.
- Resume: an in-progress round with metadata restores it (snapshot
  round-trip through the store).
- Mine økter: the felt card shows place and weapon.
- The ring setup flow is untouched (the existing spec-0008 tests keep
  passing against the shared form).

## Open questions
- Whether the felt weapon list should be narrowed by group (gruppe 1 vs 2
  weapon classes) — to confirm with the domain expert.
