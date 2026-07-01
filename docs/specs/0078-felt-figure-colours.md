# Spec 0078 — NorgesFelt figure colours

- **Status:** Accepted.
- **Related:** 0068, 0077 (feltskyting figures) — this colours them.

## Context
The field-course figures were drawn black on a white plate. The official course
prints each hold's figures in one of three colours, and the domain expert's
images confirm it: on the NorgesFelt 2026 course a **whole hold** shares one
colour — **black**, **NSF-green** or **red** — cycling across the eight holds.

## Requirements
1. Each figure is drawn in its **hold's colour**, not always black.
2. The colours match the official course: holds 1/4/7 **black**, 2/5/8 **green**,
   3/6 **red** (read from the hold overview images).

## Rationale
**Colour belongs to the hold, not the figure type.** The same shape (an egg, a
sekskant) appears in different colours on different holds, so the colour is a
property of the `FeltHoldDef`, applied to all its figures. The green/red were
sampled from the official blink images: green `#00683F`, red `#ED1C24`; black is
the existing near-black.

**A pure-Dart enum in the domain.** The domain layer is Flutter-free, so the hold
carries a `FeltHoldColour` enum (`black` / `green` / `red`); the presentation maps
it to a real `Color` via `feltHoldColour`. The figures keep the white plate and
the white inner-zone ring, matching the printed targets.

## Design
- `felt_figure.dart`: `enum FeltHoldColour { black, green, red }`.
- `felt_course.dart`: `FeltHoldDef.colour`; each hold in `norgesfelt2026` gets its
  course colour.
- `felt_figure_painter.dart`: `FeltFigureView` takes a `colour`; `feltHoldColour`
  maps the enum to a `Color`.
- `felt_course_screen.dart`: passes `feltHoldColour(hold.colour)` to each figure.

## Verification
- **Unit**: `feltHoldColour` maps the three enum values to distinct colours
  (green `#00683F`, red `#ED1C24`); `norgesfelt2026` holds carry the expected
  black/green/red per hold number.
- **Widget**: the course preview still renders all 8 holds and their figures.

## Out of scope
- Colours for a different yearly course (this is the 2026 layout).
