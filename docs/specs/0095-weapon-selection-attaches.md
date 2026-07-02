# Spec 0095 — The highlighted weapon is the attached weapon

- **Status:** Accepted
- **Related:** spec 0007 (weapons), 0008 (setup step), 0092 (shared setup form)

## Context

The weapon picker highlights the session-scoped selection
(`selectedWeaponProvider`), but the setup form's own `_weapon` starts null
and is only set by a fresh tap. So on the second session of the day the
previously chosen weapon **looks** selected — checkmark and all — while the
session is silently recorded **without** a weapon unless the shooter taps it
again. What looks chosen must be what is attached.

## Requirements

1. Opening the setup form with a weapon already selected (from earlier in
   the app run) attaches that weapon to the session **without** a new tap —
   provided it is permitted for the flow's discipline/classes.
2. A selected weapon that is **not** permitted for this flow (e.g. a rifle
   for a pistol program) is neither highlighted as attached nor attached.
3. Tapping another weapon still switches the attachment (unchanged).

## Rationale

One-line truth restoration: the form seeds `_weapon` from the same provider
the picker highlights from, filtered by the same permission rule. Remembering
the weapon **across restarts** (persisting the selection) is a follow-up, not
this fix.

## Verification

### System tests
- `session_setup_screen_test`: with a permitted weapon pre-selected in the
  container and **no tap** on the picker, confirming the setup threads that
  weapon into the session; with a non-permitted weapon pre-selected, the
  session records no weapon.

## Open questions
- Persist the last-used weapon per discipline across restarts (spec 0019's
  store) — later increment.
