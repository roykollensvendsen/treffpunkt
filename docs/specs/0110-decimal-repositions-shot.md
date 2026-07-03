# Spec 0110 — Picking a decimal moves the shot to match it

- **Status:** Accepted
- **Related:** spec 0107 (decimal entry — amended by this spec), 0002
  (move a shot), 0001 (the decimal model); user request

## Context

Spec 0107 records the picked tenth on the shot, but the marker stayed
where the shooter tapped — so a shot read off Megalink as 9,7 could sit
drawn at the 9,1 radius, and a picked 10,9 did not enter the inner-ten
ring. The user asked for the shot to move in/out from the centre to
match the decimal that is set.

## Rationale

The decimal model (spec 0001) maps distance bands to tenths, so it
inverts cleanly: each (ring, tenth) has a band, and placing the shot at
the band's midpoint makes the derived decimal read back exactly the
picked value. Moving radially — along the shot's own direction from the
centre — keeps the tap's aim direction while making the *distance* tell
the truth. Everything then agrees by construction: the marker, the
decimal, the ring (bands never cross ring lines) and the inner-ten flag
(a picked 10,9 lands inside the X-ring, as it did on the real target).
With the position truthful again, the spec-0107 drag rule simplifies: a
manual drag afterwards re-derives the decimal from where the shot lands
(the keep-within-ring exception is retired — it existed only because
the position used to disagree with the reading).

## Requirements

1. Picking a tenth moves the shot radially to the midpoint of that
   tenth's distance band within its plotted ring; the derived decimal of
   the new position equals the picked value, the ring is unchanged, and
   the direction from the centre is kept (a dead-centre shot is given
   one). The inner-ten flag follows the new position.
2. A miss is not repositioned (nothing to position; it stays 0,0).
3. Dragging a shot re-derives its decimal from the new position — the
   position is always the truth (amends spec 0107 req 3).

## Verification

- `decimal_entry_test`: every tenth of a ring round-trips through the
  moved position; higher decimals sit closer to the centre; the ring and
  the direction are preserved; a dead-centre shot gets a position; a
  picked 10,9 lands inside the inner ten; a miss is untouched.
- `decimal_entry_flow_test`: picking a tenth in the recorder moves the
  stored shot so its derived value equals the pick; a manual drag
  afterwards clears the pick and re-derives from the position.
