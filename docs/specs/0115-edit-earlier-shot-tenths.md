# Spec 0115 — Adjust the decimals of earlier shots

- **Status:** Accepted
- **Related:** forum thread «Ønsker å kunne justere desimalene på
  tidligere skudd» (planned by the owner); spec 0107 (decimal entry —
  this was on its deferred list), 0110 (a picked tenth repositions the
  shot), 0114 (decimals on every ring face)

## Context

Spec 0107 put the tenth picker on the **last** placed shot only;
earlier rows show their decimal as read-only text. In practice the
shooter reads the values off the Megalink display a few shots at a
time, so a mistyped tenth is often noticed only after more shots have
been plotted — and by then it can no longer be corrected.

## Rationale

Everything below the widget already handles any index: the domain
(`Series.setShotTenth(index, …)`), the notifier (`setShotTenth` moves
the shot to the sub-band midpoint per spec 0110) and the shot list
(which passes the row index through `onTenthPicked`). The only gate is
the row widget's "last shot only" condition. Removing it gives every
placed shot in the current series the same compact picker the last
shot has — one interaction pattern, no new mode, no new state. Shots
in already-sealed series stay read-only: the seal is the boundary of
the series (spec 0004) and the scorecard is a record, not an editor.

## Requirements

1. In decimal mode, every placed scoring shot (ring > 0) in the current
   series offers the tenth picker, not just the last one. A miss stays
   0,0 — nothing to pick.
2. Picking a tenth on an earlier shot behaves exactly as on the last:
   the value snaps to the sub-band midpoint (spec 0110), the decimal
   totals recompute, the integer total is untouched.
3. Sealed series remain read-only, as does everything outside decimal
   mode.

## Verification

- `decimal_entry_flow_test`: after two shots, both rows carry pickers;
  adjusting the FIRST shot's tenth updates the decimal sum and moves
  that shot (the second is untouched); outside decimal mode no picker
  appears (existing case).
- Existing 0107/0110/0114 suites pass unchanged in behaviour (the
  "picker follows the last shot" case is generalised to "every placed
  shot has one").
