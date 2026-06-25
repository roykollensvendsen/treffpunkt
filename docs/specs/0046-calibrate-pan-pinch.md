<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0046 — Calibrate the scan overlay by drag & pinch

- **Status:** Accepted
- **Related:** spec 0039 (scan + the original two-handle calibration), spec 0045
  (zoom while placing)

## Context

The scan calibration (spec 0039) fitted the ring overlay to the photographed
target with **two small handles** — a centre dot and an outer-ring dot. They were
fiddly to hit, especially on a phone, and you couldn't move *and* resize fluidly.
The natural gesture is to **drag the rings to move them and pinch to resize
them** onto the target, like manipulating any object.

## Requirements

1. **Drag to move, pinch to scale** the ring overlay onto the photographed
   target, replacing the two handles. A pinch resizes about the fingers (the
   point under the fingers stays put).
2. **Unchanged placement.** In the placement step, tapping to place, dragging a
   marker, and zooming the photo (spec 0045) are unchanged.
3. **Scoring unaffected.** Calibration stays a similarity transform (centre +
   uniform scale); only the *way it is set* changes.

## Design

- The calibration state becomes `centre` (a `PixelPoint`) + `pixelsPerMm`,
  seeded centred with the outer ring ~⅓ of the box across.
- In the calibrate step the overlay `GestureDetector` uses `onScaleStart` /
  `onScaleUpdate` (the `InteractiveViewer` is disabled there, so a one-finger
  drag moves the overlay and a pinch scales it, rather than panning the view).
  The maths is a pure, unit-tested function `calibrationAfterGesture(...)`:
  `centre = focal + scale·(startCentre − startFocal)`, `pixelsPerMm =
  startPixelsPerMm · scale` — a one-finger drag (`scale == 1`) translates the
  overlay; a pinch scales it about the focal point.
- The two `Positioned` handles (and their keys) are removed. The ring overlay
  itself is the visual.

## Verification

- **Unit (`calibration_gesture_test`):** a one-finger drag moves the centre by
  the finger delta and leaves the scale; a pinch doubles `pixelsPerMm` and keeps
  the focal point fixed (the overlay grows around it).
- **Widget (`scan_target_screen_test`):** calibration shows the overlay + confirm
  (no handles, no zoom controls); a drag in calibration still reaches placement;
  all placement / zoom / auto-detect / contribution tests stay green.
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.
- **Manual:** scan a target, drag the rings over it and pinch to size them to the
  printed rings, then place shots.

## Known limitations / next increment

A straight-on photo is still assumed (a similarity transform, no perspective /
rotation). A future step could add rotation or a perspective fit for angled
photos.
