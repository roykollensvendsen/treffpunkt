# Spec 0079 — Composed NorgesFelt hold layout

- **Status:** Accepted.
- **Related:** 0068 (feltskyting), 0077 (accurate figures), 0078 (figure
  colours) — this composes them into the real hold layout.

## Context
The course preview drew each hold as a horizontal **strip of separate figures**,
each on its own white plate. The real NorgesFelt target sheets are **one
composed picture per hold**: the figures sit at specific positions and sizes
relative to one another, some are white shapes **knocked out of a coloured
backing plate**, adjacent **målgrupper are divided by a black vertical line**,
and each figure carries a thin **inner-treff ring**. The domain expert asked for
the holds to be reproduced as faithful vector graphics matching the official
images.

The eight holds were reconstructed from the official images with the
measurement harness in `tool/felt/` (`models/hold-{1..8}.json`), each checked
against its source image (match score 0.95–0.98 of the physical resolution
ceiling, sub-pixel median boundary error). This spec brings those composed
models into the app.

## Requirements
1. Each hold renders as **one composed picture** matching the official sheet:
   backing plate(s) in the hold colour, figures at their real relative
   size/position/rotation, white knockouts where the target knocks a figure out
   of a plate, the **black vertical separator line(s)** between målgrupper, and
   each figure's **inner-treff ring** (correct centre, radius and colour).
2. The **C-figures are truncated circles** (a circle cut flat across the
   bottom), not full circles.
3. The course preview shows all **8 holds**, each with its header (hold number,
   distance, position) and the list of figure names, above the composed picture.
4. The figure geometry is **reconstructed vector data** — no source images ship
   in the app.

## Rationale
**A composed art model, generated from the measured reconstruction.** Each hold
is a `FeltHoldArt`: a canvas size, the paper colour, the backing `plates`, the
`figures` (each a circle / truncated circle / ellipse / minimal polygon with a
fill colour and an optional inner ring), and the black `separators`. The data is
**generated** from the committed `tool/felt/models/*.json` into
`felt_hold_art_data.dart` (as the traced outlines in `felt_figure_paths.dart`
already are), so the app carries only reconstructed vector data and the numbers
stay traceable to the harness.

**Presentation layer, like the existing figure paths.** The art model uses
`dart:ui` geometry/colour, so it lives in `presentation/` beside
`felt_figure_paths.dart`; the pure-Dart domain (`FeltHoldDef`) is unchanged and
still supplies each hold's metadata (number, distance, position, figure names).

**Coordinates in the model's own pixel space.** Each hold keeps the pixel size
and coordinates it was measured in; the painter scales the whole hold to the
card width, so the figures keep their true **relative** proportions within the
hold (the property the official sheet shows). The per-figure strip
(`FeltFigureView`) is kept for the later recording UI, where single figures are
shown and tapped.

## Design
- `felt_hold_art.dart` (presentation): `FeltHoldArt`, `FeltArtPlate`,
  `FeltArtSeparator`, `FeltArtFigure` (a `FeltArtShape` enum +
  circle/tcircle/ellipse/polygon parameters), `FeltArtRing`.
- `felt_hold_art_data.dart` (generated): `const List<FeltHoldArt>
  norgesfelt2026Art`, one entry per hold, emitted by `tool/felt/gen_dart.py`
  from `models/hold-N.json`.
- `felt_hold_art_painter.dart`: `FeltHoldArtPainter` draws paper → plates →
  figures (fill + inner ring) → separators, scaled to the paint size;
  `FeltHoldArtView` sizes it to the hold's aspect ratio.
- `felt_course_screen.dart`: each hold card renders `FeltHoldArtView` with a
  figure-name caption instead of the figure strip.

## Verification
- **Unit** (`felt_hold_art_data_test.dart`): `norgesfelt2026Art` has 8 holds
  numbered 1–8; the paper is white; hold 1 has one black plate and two figures;
  holds 2/3/6/8 each carry ≥1 black separator; holds 3 and 6 include
  `FeltArtShape.tcircle` figures; every figure with a ring has a positive
  radius; hold 2 has three white-fill (knockout) figures.
- **Unit** (`felt_hold_art_painter_test.dart`): the painter paints a hold to a
  canvas without throwing; `shouldRepaint` is true for a different hold and
  false for the same one; a `tcircle` produces a path narrower at the bottom
  than a full circle.
- **Widget** (`felt_course_screen_test.dart`): the preview renders all 8 hold
  cards, a `FeltHoldArtView` per hold, the `Hold 1`/`Hold 8` headers and the
  figure-name captions (e.g. `Hare`, `Ulvehode`).

## Out of scope
- Recording/scoring hits on the composed holds (later increment).
- A different yearly course than NorgesFelt 2026.
