<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0045 — Zoom & pan the scan photo while placing shots

- **Status:** Accepted
- **Related:** spec 0039 (scan), spec 0021/0022 (the live target owns its
  gestures / pinch-zoom)

## Context

On the scan screen (spec 0039) the photo was shown at a fixed size, so marking a
hole precisely was hard — a small hole on a phone-sized photo is only a few
pixels. The shooter needs to **zoom in and pan around the photo (with its placed
markers)** to mark and adjust hits accurately, the same way the live target
already supports zoom (specs 0021/0022).

## Requirements

1. **Zoom + pan in placement mode.** While placing shots, the shooter can pinch
   to zoom, drag to pan, and use on-photo **＋ / reset / −** buttons (and trackpad
   scroll). Tapping to place and long-pressing to drag a marker keep working —
   the tap is mapped back through the zoom, so scoring is unaffected.
2. **Calibration unchanged.** While calibrating, the two handles are still
   dragged directly (zoom/pan off in that step, so a single-finger drag moves a
   handle rather than panning).
3. **Reset.** Zoom resets when a new photo is picked or on "Ta nytt bilde".

## Design

- Wrap the photo stack (image + ring/marker overlay + handles) in an
  `InteractiveViewer` driven by a `TransformationController`, mirroring
  `SeriesTarget`: `minScale 1`, `maxScale 6`, `trackpadScrollCausesScale`.
  `panEnabled` / `scaleEnabled` are **on only in placement mode** (`!calibrating`)
  so the calibrate handles' direct drag never competes with view panning.
- The overlay `GestureDetector` is the `InteractiveViewer`'s descendant, so its
  `localPosition` arrives already in the photo's own (untransformed) space — the
  existing `_calibration.shotFor(localPosition)` is unchanged and correct at any
  zoom. The painter draws markers/rings in that same space, so they zoom/pan with
  the photo.
- A compact `_ScanZoomControls` (＋ / reset / −) sits over the photo in placement
  mode, outside the `InteractiveViewer` so the buttons themselves don't transform.
- The controller resets to identity on a new pick and on retake.

## Verification

- **Widget (`scan_target_screen_test`):** the zoom controls appear in placement
  mode and not while calibrating; after zooming in, a centre tap still scores a
  ten (the tap is mapped back through the zoom). Existing placement / calibrate /
  detect / contribution tests stay green (the `InteractiveViewer` doesn't change
  tap/long-press mapping).
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.
- **Manual:** scan a target, reach placement, pinch-zoom into a cluster, pan,
  and mark/adjust holes precisely; the markers track the photo.

## Known limitations / next increment

Zoom is in placement mode only; calibration is still done at 1× (the handles are
coarse alignment). If aligning the rings needs zoom too, a follow-up can unify
the handles into the overlay so the calibrate step can zoom as well.
