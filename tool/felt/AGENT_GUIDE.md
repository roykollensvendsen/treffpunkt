<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# Reconstructing one NorgesFelt hold as a vector model — agent guide

You reconstruct **one hold** of the NorgesFelt 2026 course as a vector model
(`tool/felt/models/hold-N.json`) that, when rendered, matches the official hold
image as closely as the image resolution physically allows.

## Commands (run from `tool/felt/`)
```
python3 analyze.py <IMG> <N>                 # measurement report (JSON → stdout)
python3 compare.py models/hold-N.json <IMG>  # metrics (JSON)
python3 panel.py   models/hold-N.json <IMG> out/hold-N.png   # 3-panel image
```
- `<IMG>` is the absolute path to `holdN-2026.png` (given in your task).
- **Also `Read` the image** — use your own eyes together with the numbers.
- The report lists ink **components**; each has `bbox`, `colour`, fitted
  `fitCircle`/`fitEllipse` (with `rms`/`mismatch`), `polyMinimal` &`polyFine`
  point lists, any `knockouts` (a shape knocked out of a plate, e.g. a white
  figure in a coloured plate) with their own `innerRing`, and an `innerRing`
  for solid figures. Colour holds also report `blackSeparators`.

## Model schema (coords are in the `artCrop` pixel space from the report)
```json
{"hold":N, "artCrop":[x,y,w,h], "size":[w,h], "paper":[255,255,255],
 "plates":[{"rect":[x,y,w,h],"color":[r,g,b],"radius":px}],
 "figures":[{"type":"circle|ellipse|polygon","params":{...},
             "fill":[r,g,b],
             "inner":{"cx":,"cy":,"r":,"strokeW":1.8,"color":[r,g,b]}}],
 "separators":[{"rect":[x,y,w,h],"color":[16,16,16]}]}
```
- `circle` params `{cx,cy,r}`; `ellipse` params `{cx,cy,a,b,theta}`;
  `polygon` params `{points:[[x,y],...], theta?}`.
- Render order: paper → plates → figures (fill, then inner ring) → separators.
- `tool/felt/models/hold-1.json` is a **worked example** (a black plate with a
  white hare knockout + an egg). Read it.

## How to map the report to the model
- **Plate**: a large component whose `colour` is the hold colour (or black) and
  that contains a big `knockout` → emit a `plate` (rounded `rect` from its
  `bbox`, `radius` ~6) in the hold colour.
- **Knockout figure** (white figure in a plate): emit a `figure` with
  `fill:[255,255,255]`, shape from the knockout's `polyMinimal` (or `circle`/
  `ellipse` if that fits with low error), and its `innerRing`
  (`color` = the plate colour, since the ring reads as the plate colour).
- **Solid coloured figure** (on white paper): `fill` = its `colour`; inner ring
  `color` = white `[255,255,255]` (rings on coloured figures read light).
- **Shape choice — minimise vertices**: use `type:"circle"` when `fitCircle.rms`
  is small (≲1.5); `type:"ellipse"` when `fitEllipse.mismatch` ≲0.03; otherwise
  `polygon` with `polyMinimal`. Prefer `polyMinimal` over `polyFine`
  (fewer points fit the anti-aliased edge *better*, not worse).
- **Rotation**: bake rotation into `polygon.points` (they are already in place),
  or set `ellipse.theta` / `polygon.theta` from `pcaAngleDeg` when using a
  primitive.
- **Separators**: for each entry in `blackSeparators`, emit a `separator` rect
  (translate to artCrop space: subtract the report's `artCrop` x,y).
- **Coordinates**: report bboxes/points are already in artCrop space — copy them
  through unchanged. Colours: black `[16,16,16]`, green `[0,104,63]`,
  red `[237,28,36]`, white `[255,255,255]`.

## Acceptance bar (loop until met, or best after ~5 rounds)
At this native resolution a hard-edged vector cannot exceed ~0.95 raw IoU
(`ceiling` in the metrics), so target the **ceiling-relative** score:
- `matchScore ≥ 0.95` (aim 0.97), **and**
- `boundaryPx.median ≤ 1.5`, **and**
- `colour ≥ 0.90`, **and**
- visually (in the panel) the figure count, shapes, colours, rotations,
  relative sizes/positions, inner rings and separators all match.

Iterate: run compare, inspect the panel, adjust the JSON (shape type, points,
ring centre/radius/colour, plate radius, separators), repeat. Report the final
model path and its metrics.
