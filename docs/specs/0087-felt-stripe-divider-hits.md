# Spec 0087 — Felt: a hit on a stripe's divider lines counts

- **Status:** Accepted
- **Related:** spec 0086 (stripe grouping), 0080 (hit recording)

## Context

The tre-kvadrater stripes on Hold 2 and Hold 8 are drawn as three squares
with thin white divider lines between them (spec 0086). The hit test only
recognised the squares themselves, so a shot placed **on a divider line**
scored as a **miss** — zero points for a shot visibly inside the figure. The
domain expert flags this as wrong: the dividers are part of the figure.

## Requirements

1. A shot on the divider between two squares of a stripe scores as a **hit
   on that stripe** (treff + the figure's point, spec 0085), not a miss.
2. A divider hit is **not** an innertreff — only the middle square itself is
   the inner zone (spec 0086).
3. Shots outside the stripe's outline are still misses.

## Rationale

The divider band is 1–2 px wide in hold-pixel space and lies strictly inside
the stripe's bounding rectangle, so the bounding box of a stripe's grouped
parts *is* the stripe's true outline — testing it after the individual
shapes adds no false hits elsewhere (no other figure overlaps a stripe's
box, and real shapes win because they are tested first).

## Design

`feltHitTest` (spec 0086) gets a second pass: when no shape contains the
point, the union bounding box of each `scoreIndex` group's parts is tested;
a containing box resolves to that group's figure with `inner` false.

## Verification

### Unit tests
- `felt_hit_test_test`: on the real hold-2 art, a point in the vertical
  divider of the top stripe (between squares 4/5 and 5/6) hits figure 4 with
  `inner` false; on hold 8, a point in the horizontal divider of the Stor
  stripe hits figure 2; a point outside a stripe stays a miss.

## Open questions
- None.
