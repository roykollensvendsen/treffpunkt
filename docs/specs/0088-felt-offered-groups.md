# Spec 0088 — Felt: only Gruppe 1 and Gruppe 2 are offered

- **Status:** Accepted
- **Related:** spec 0080 (hit recording — the group picker)

## Context

The recorder's group picker offers Gruppe 1, 2 and 3. Per the domain expert,
**Gruppe 3 is not shot** on the NorgesFelt course — it is the class for
heavier weapons — so offering it only invites mis-recorded rounds.

## Requirements

1. The group picker offers **Gruppe 1 and Gruppe 2 only**.
2. A round already stored with Gruppe 3 still loads (save/resume, Mine
   økter, sync) — the group stays resolvable, exactly like retired programs
   stay resolvable by name (spec 0036 precedent).

## Rationale

Removing the enum value would break `FeltShooterGroup.values.byName` for any
stored round; the established pattern is retained-but-not-offered (the
catalogue keeps air rifle resolvable while the picker hides it).

## Design

`FeltShooterGroup` gains a const `offered` list (`[one, two]`) and the group
picker loops it; the enum keeps `three` with a doc comment saying why.

## Verification

### Unit tests
- `felt_scoring_test`: `offered` is exactly Gruppe 1 and 2; Gruppe 3 remains
  a member with 5 shots per hold.
- `felt_session_snapshot_test`: a snapshot stored with group `three` still
  round-trips through JSON.

### System tests
- `felt_record_screen_test`: the picker shows buttons for Gruppe 1 and 2 and
  none for Gruppe 3.

## Open questions
- None.
