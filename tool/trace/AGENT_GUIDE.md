<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# Tracing a reference drawing into a Dart pictogram — agent guide

You turn a **reference image** (a technical drawing, schematic, sketch or clean
photo of one object) into a minimal-vertex vector pictogram and emit it as a
Dart `CustomPainter` matching the shapes in
`lib/core/presentation/category_pictograms.dart`. This is *measure-driven*, not
freehand — the tool traces the real edges and you verify the fit by eye.

## Never commit the source images
Reference drawings are usually someone else's copyright. `tool/trace/.gitignore`
blocks `out/` and stray images — keep it that way. Sources live only in the
session scratchpad. What you commit is the *vector* (a handful of numbers) and
the Dart class, not the picture.

## Commands (run from `tool/trace/`)
```
# whole silhouette (everything that isn't paper):
python3 trace.py <IMG> --out out/x.png

# named colour regions (a two-tone object), each its own polygon:
python3 trace.py <IMG> \
    --region case:0.35,0.45:8 --region bullet:0.82,0.45 --eps 2.5 \
    --out out/x.png > out/report.json

# generate the Dart class from the report:
python3 gen_dart.py out/report.json --name Cartridge \
    --colour case=0xFFC4963A --colour bullet=0xFFB2603A
```
- `<IMG>` is the absolute path to the reference (given in your task).
- **Always `Read` both the source image and `out/x.png`** — the panel is
  *vector | overlay | original*, left→right. Judge with your eyes, not just the
  IoU.

## `--region NAME:SPEC[:CLOSE]`
- `NAME` becomes the Dart field (`static const List<Offset> NAME`). Avoid Dart
  keywords; `gen_dart.py` renames `case`→`caseOutline` etc. automatically.
- `SPEC` is either `x,y` (a 0..1 point whose colour is *sampled* from the image
  — easiest) or `r,g,b` (an explicit target colour).
- `CLOSE` (optional) is that region's own morphological close in px — see the
  split-fill gotcha below. Overrides the global `--close`.
- All regions in one run share **one normalisation box**, so their polygons
  line up when painted on top of each other. Regions are painted in listed
  order — **first region = bottom layer.**

## Reading the report
Per region: `points` (normalised 0..1, y-down), `vertices`, and `fitIoU` (the
traced polygon vs the source mask). `aspect` is width ÷ height of the union box
— it becomes the pictogram's `static const double aspect`.

## The acceptance bar
- `fitIoU` **≥ 0.98** per region (the bullet/case here hit 0.99),
- the **fewest vertices** that still trace the shape — raise `--eps` until the
  overlay just starts to deviate, then back off. Fewer points fit *better*, not
  worse (extra vertices chase anti-alias jaggies), and read cleaner at 26 px.
- the overlay panel looks right to your eye, **and** the final Dart pictogram,
  rendered at tile size (26 px) in light + dark, is signed off before any PR.

## Hard-won gotchas
- **An internal line splits a fill into pieces.** A dash-dot centreline or a
  dimension line drawn *through* a coloured region cuts it into several blobs,
  so the largest-component grab returns a sliver (IoU collapses). Bridge it with
  a per-region `:CLOSE` (e.g. `case:...:8`) — morphological close welds across a
  thin dark line. Start small (2–3) and raise until the region is whole.
- **One close does not fit every region.** A big close that welds a boxy case's
  rim to its body will pucker a smooth bullet nose into facets (vertex count
  explodes). Give each region its own `:CLOSE`; leave curved parts at 0–2.
- **A detached part of the same colour** (a cartridge rim outside the body's
  black border) is recovered with `--keep-frac 0.05` (union every blob ≥ 5 % of
  the largest) — but only a `--close` big enough to weld them lets a *single*
  contour trace the combined silhouette. If they can't be welded, trace the
  part as its own `--region` instead.
- **Paper is auto-detected from the four corners** (usually pure white 255).
  Pass `--paper r,g,b` if the drawing sits on a tint.
- **Sample colours from a flat interior**, away from edges and labels —
  anti-aliased edge pixels are a blend and widen the needed `--tol`.
- **Angular silhouettes** (a hand sketch, a faceted trace) smooth with
  `--chaikin 1`. Don't over-smooth a shape whose corners are real.
- `gen_dart.py` emits whole-number coordinates as int literals and a
  `const CustomPaint`, so the class passes `very_good_analysis` as-is; you still
  fill the doc comment and the `spec NNNN`.

## After the trace
Paste the emitted classes into `category_pictograms.dart` (it already has the
shared `_fit`/`_polyPath` helpers), wire the pictogram into its screen, then
render at tile size for sign-off. From there it's the normal spec-first + TDD
increment — see the `reference-to-pictogram` skill for the full flow.
