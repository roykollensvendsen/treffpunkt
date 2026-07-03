# Spec 0121 — The luftduell face wears its own black

- **Status:** Accepted
- **Related:** forum thread «skiver» (planned by the owner; approach
  confirmed on the thread: «vi prøver det»); specs 0043/0044 (the
  Sprintluft/Storluft programs), 0113 (ring values and sighting
  lines), nasjonalt regelverk § 5.1.18.1.2

## Context

The app drew the 10 m luftduellskive all black, exactly like the 25 m
duel face — the two were indistinguishable on screen, and the domain
expert read that as Storluft using the wrong face («10 m
luftduellskiver … har en annen inndeling på ringene. gjelder bare
luftpistol»). The zone radii were already correct (§ 5.1.18.1.2,
verified for spec 0113); the drawing was not.

## Rationale

The rulebook figure for the 10 m luftduellskive shows the aiming
black covering only the inner zones: the 8 and 9 digits sit white on
black, the 7 and outward sit black on white — so the black is the
8-zone, ⌀ 76,0 mm, on the ⌀ 155,5 mm face. The white sighting lines
(42,5 × 3 mm) replace the side values: in the figure they run from
the face's edge inward, cutting a white channel through the outer
rings and a small notch into the black's edge. Anchoring the painted
lines at the outermost ring's edge reproduces that — and leaves the
25 m duel face untouched, since there the black IS the outermost ring
(⌀ 500 mm), so the anchor is the same point it always was. The
spec-0113 label colouring keys off the black diameter and adapts by
itself (8–9 white, 5–7 dark).

## Requirements

1. `TargetGeometry.airDuel10m` carries `blackBullDiameterMm: 76.0`
   (the 8-zone), per the § 5.1.18.1.2 figure.
2. The sighting lines are anchored at the outermost scoring ring's
   edge, running inward; the 25 m duel face renders exactly as
   before.
3. Ring values 5–7 print dark on the white zones, 8–9 white on the
   black — no code change, verified by test.

## Verification

- Geometry: `blackBullDiameterMm == 76.0` on the luftduell face; the
  25 m rapid face stays 500.
- Painter: the luftduell sighting-line rects start at the outermost
  ring's edge and end inside the black's edge; the 25 m rapid face's
  rects are unchanged (black edge == outer ring edge).
- Screenshot: the two duel faces are visually distinct.
