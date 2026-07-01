# Spec 0077 — Accurate NorgesFelt figures

- **Status:** Accepted.
- **Related:** 0068 (feltskyting figures & course) — this replaces its
  approximated shapes with faithful traces.

## Context
The first figure set (spec 0068) drew several figures as rough parametric
approximations: the **1/6** and **bowling pin** as rounded rectangles, the
**stripe** as a full pill, the **triangle** as a sharp apex-up triangle, and the
animals were traced from low-resolution hold thumbnails. The domain expert
supplied the **official high-resolution blink images**, which show the true
shapes — including that the big "Trekant stor" is a **right-angled** triangle,
distinct from the small rounded "Trekant".

## Requirements
1. Each figure matches its official blink image: the **1/6** (rounded wedge), the
   **bowling pin**, the **sekskant**, the **egg**, the small **rounded triangle**
   and the big **right-angled triangle**, and the three animals (hare, wolf head,
   ptarmigan).
2. The figures keep their real relative sizes and the inner-zone ring.

## Rationale
**Trace every figure from the official images.** All figures except the exact
circle/oval are now closed polygons traced (potrace) from the supplied blink
images, normalised to a 0..1 box and **oriented as they sit on the course** (some
source images are rotated 90° from the course orientation; the rotation is baked
into the stored outline, so the painter just scales it). The stripe stays a
near-rectangle (its plates). The source images are **not** committed — only the
reconstructed vector outlines, as before.

**A distinct right-triangle type.** "Trekant stor" is a right triangle, not a
scaled-up rounded triangle, so it gets its own `FeltFigureType.rightTriangle`;
Hold 5 uses it. The inner ring for every traced figure sits at the outline's
area centroid.

## Design
- `felt_figure_paths.dart` (generated, replaces `felt_animal_paths.dart`): the
  traced outlines `feltHareOutline`, `feltWolfHeadOutline`,
  `feltPtarmiganOutline`, `feltReducedFigureOutline`, `feltBowlingPinOutline`,
  `feltHexagonOutline`, `feltTriangleOutline`, `feltRightTriangleOutline`,
  `feltEggOutline`.
- `felt_figure.dart`: add `FeltFigureType.rightTriangle`.
- `felt_course.dart`: Hold 5's "Trekant stor" → `rightTriangle`.
- `felt_figure_painter.dart`: `figurePath` renders each type from its outline
  (circle/oval stay `addOval`, stripe a small-radius rect); `figureCentroid` uses
  the polygon centroid for every traced type.

## Verification
- **Unit** (`felt_figure_painter_test.dart`): circle/oval/stripe centre on the
  box; every traced centroid lies inside the box; the apex-up triangle and the
  hare carry their mass below the middle; every `FeltFigureType` builds a
  non-empty path.
- **Widget**: the course preview still renders all 8 holds and their figures.
- The traces were re-rendered from the generated Dart and checked against the
  source images during reconstruction.

## Out of scope
- Per-figure inner-ring position from the images (the centroid is used); the
  stripe's internal plate divisions.
