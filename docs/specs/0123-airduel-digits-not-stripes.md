# Spec 0123 — Tall, ikke striper, på luftduellskiva

- **Status:** Accepted
- **Related:** forum thread «skiver» (reopened by the domain expert's
  verdict); spec 0121 (the black), 0113 (ring values), nasjonalt
  regelverk § 5.1.18.1.2

## Context

Spec 0121 drew the luftduell face per the rulebook TEXT: white
sighting lines (42,5 × 3 mm) replacing the side values. The domain
expert, sheet in hand, says otherwise: «de skal bare ha tall, ingen
hvite striper på sprintluft skive». The rulebook contradicts itself —
its own figure shows ordinary digits 5–9 on both axes and no lines —
and the physical sheet agrees with the figure.

## Rationale

The physical sheet is the truth the shooter compares against, so it
trumps the rulebook text. The face already prints vertical digits;
turning on the horizontal axis and dropping the sighting lines makes
the drawing match the sheet and the figure exactly. The 25 m duel
face keeps its lines — those are the GTR's (§ 6.3.4.4), a different
sheet, expert-verified earlier.

## Requirements

1. `airDuel10m` prints values 5–9 on BOTH axes and has no sighting
   lines; the 25 m duel face is unchanged.

## Verification

- Geometry: no sighting line on `airDuel10m`; labels on both axes.
- Painter: the luftduell face paints 5 × 4 digits and only the paper
  rect; the 25 m rapid face still paints its two lines.
- Screenshot compared against the rulebook figure.
