# Spec 0127 — Lesbare ringtall på skjermen

- **Status:** Accepted
- **Related:** forum thread «Duellskiver» (planned by the owner; the
  report: «25 m duellskiva … mangler verdier på ringene vertikalt»,
  approach confirmed: «du kan prøve å øke størrelsen på tallene»);
  spec 0113 (ring values)

## Context

Spec 0113 printed the ring values sheet-true and skipped them below
4 px. On the 25 m duel face that meant they never showed at all: 5 mm
digits on a 50 cm face are ~3,5 px on a phone-sized target, so the
face looked unnumbered — the bug report. The luftpistol digits (2 mm
on 15,5 cm) squeaked past at ~4,3 px but were barely legible.

## Rationale

A paper sheet is read from metres away through a spotting scope; a
phone is read from 30 cm. Sheet-true sizes are the wrong unit on
screen — legibility is the requirement, fidelity of *placement* the
constraint. New rule, uniform for every face: a digit draws at the
sheet-true size **floored at 10 px** (a comfortably legible minimum),
and is skipped only when it would not fit inside its own ring band —
the geometric fact that made the old mini-target skip right. Review
minis keep skipping (their bands are a few px); every live shooting
target now shows its values.

## Requirements

1. Ring values draw at `max(sheet-true px, 10 px)`.
2. A ring's value is skipped when the floored size exceeds the ring's
   band width in px (it would smudge across rings) — which keeps the
   scorecard mini-targets clean.
3. The rule is a pure, unit-tested function.

## Verification

- Unit: the floor, the band-fit skip and the sheet-true passthrough
  above 10 px.
- Painter: the 25 m duel face paints its 5 × 2 values at the DEFAULT
  test size (where it painted none before); the mini air-pistol
  target still paints none.
- Screenshot of the 25 m duel face at phone size with visible values.
