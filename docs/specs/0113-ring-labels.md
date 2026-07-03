# Spec 0113 — Ring values printed on the target faces

- **Status:** Accepted
- **Related:** forum thread «Skiver» (planned by the owner, with the
  gtr-2026 sheet excerpts as the source); specs 0103 (inner-ten ring),
  0004/0005 (face geometry)

## Context

The real NSF/ISSF sheets print the ring values in the scoring zones; the
app's drawn faces showed bare rings. The domain expert asked for the
values on all faces, and supplied the official rulebook pages
(skyting.no, gtr-2026) that specify them exactly.

## Rationale

The rulebook gives one convention per face, so the painter reads it as
per-face metadata on `TargetGeometry` (like the inner ten):

| Face | Values | Directions | Digit height | Sighting lines |
|---|---|---|---|---|
| 10 m luftpistol (and air rifle) | 1–8 | both axes | 2 mm | — |
| 25 m presisjon / 50 m | 1–9 | both axes | 10 mm | — |
| 25 m duell/silhuett | 5–9 | vertical only | 5 mm | 125 × 5 mm |
| 10 m luftduell (Sprintluft/Storluft) | 5–9 | vertical only | 2 mm | 42,5 × 3 mm |

The luftduell row was not among the supplied pages; per the expert's
direction it was sourced from the national pistol rulebook on skyting.no
(§ 5.1.18.1.2), whose zone table matches the app's geometry exactly.
Zones above the max are unnumbered on the sheets. The duel faces replace
their side values with two white horizontal **sighting lines** running
inward from the black's edge. Digits are centred in their ring band and
follow the on-the-black colour rule the rings and the inner-ten ring
already use. Sheet-true digit sizes become unreadable smudge on the
small review targets, so labels are skipped below a readability floor
(4 px) — the big shooting target always clears it.

## Requirements

1. `TargetGeometry` carries the label convention (`ringLabelMaxValue`,
   `ringLabelsBothAxes`, `ringLabelHeightMm`, `sightingLineLengthMm`,
   `sightingLineWidthMm`), set per the table above.
2. `SeriesPainter` draws each numbered ring's digit centred in its band,
   at the specified positions and mm-true size, white on the black —
   and the duel faces' two sighting lines at their face's dimensions.
3. Labels are skipped when the mm-true size maps below 4 logical px.

## Verification

- `series_painter_test`: air pistol paints 8×4 digits; precision 9×4;
  the 25 m duel and luftduell faces 5×2 each plus exactly two
  sighting-line rects; a mini-target-sized canvas paints none.
- Visual review by screenshot against the sheet excerpts.
