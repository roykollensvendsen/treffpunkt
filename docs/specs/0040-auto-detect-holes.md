<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0040 — Auto-detect bullet holes in a scan

- **Status:** Accepted
- **Related:** spec 0039 (manual-assisted scan), ADR-0021 (the scan's
  calibration + image-source seam), ADR-0022 (the pure-Dart detection approach)

## Context

Spec 0039 lets a shooter photograph the target, align the ring overlay and tap
each hole. The sequel (foreseen in ADR-0021) is **detecting the holes
automatically** so the taps are pre-filled. Decided with the domain expert: the
**pure-Dart heuristic** route, not ML — robust ML needs a labelled NSF-target
dataset that does not exist yet and runs native-only, whereas a heuristic runs
**web + mobile from one codebase**, needs no dataset, and is **pure-Dart
unit-testable**. It is *assistive*: the shooter reviews/adjusts/confirms, so it is
tuned to favour false negatives (a missed hole costs one tap) over false
positives (a phantom must be noticed and deleted). The decisive advantage over a
generic detector: the shooter has **already calibrated**, so the centre, the
scale (→ the exact expected hole size in pixels) and every printed ring / bull
position are known — strong priors that make a simple detector workable.

## Requirements

1. **Auto-detect action.** The placement step gains a **Finn treff automatisk**
   action (shown only after calibration). It analyses the photo and **appends**
   the detected holes as ordinary editable shots.
2. **Append, dedup, cap.** Detected shots are added to the existing ones,
   de-duplicated against them (a hole already marked is not stamped twice) and
   capped at the series' **remaining capacity**; it never replaces manual work.
3. **Graceful degradation.** A decode/processing failure or zero hits leaves the
   manual flow intact, each with a short hint ("Kunne ikke analysere…", "Fant
   ingen treff…"). The detector **never throws** and never blocks placement.
4. **Off the UI thread.** Decode + detection run on a background isolate, with an
   "Analyserer…" state, so a large photo never janks the screen.
5. **No regression.** Manual capture / calibrate / tap / drag / undo / confirm
   (spec 0039) are unchanged; auto-detect is purely additive.

## Design

- **`GrayField`** (`domain/gray_field.dart`) — a pure grayscale pixel grid
  (luminance 0–255), the only thing the detector and the tests touch (no `image`
  dependency in the domain).
- **`HoleDetector`** (`domain/hole_detector.dart`) — `detect(GrayField,
  {centre, pixelsPerMm, geometry, maxHoles}) → List<PixelPoint>` in **field**
  pixels (coordinate-free). All O(W·H) pure Dart: a **two-sided local-contrast
  mask** via an integral image (catches a dark-on-white hole and a light-on-black
  bull hole, robust to lighting gradients) with a **peak-contrast gate** (a real
  hole has a strong core; the faint self-halo of a blob does not); **connected
  components** filtered by area, **compactness** and aspect (rejecting thin ring
  lines); a **radial band at the bull edge** (its strong circular edge); a
  **scoring-radius cap** (a centroid beyond the outermost ring is a miss, so it
  scores nothing and on a photo is almost always a paper-margin artefact); then
  de-duplication and ranking by contrast strength. Ring *lines* are left to the
  shape filter — the inner rings are too densely spaced for per-ring radial
  rejection.
- **`shotsFromField`** (`domain/target_scan.dart`) — maps the detector's field
  centroids to `Shot`s. **Coordinate insight:** downscaling preserves aspect
  ratio, so the field→display-box map is just `BoxFit.contain` of the *field*
  into the square box (`PhotoFit`); it derives the field-space centre/scale for
  the detector, then lifts each centroid back to box space and reuses the
  **existing** `TargetCalibration.shotFor` — one calibration as the single source
  of truth.
- **`TargetScanner`** seam (`data/target_scanner.dart`) — `scan(bytes, {…}) →
  Future<List<Shot>?>` (null = couldn't process; empty = none found; never
  throws). Default `UnavailableTargetScanner`; real `ImageTargetScanner`
  (`data/image_target_scanner.dart`, the only file importing `image`) decodes,
  bakes EXIF orientation, downscales so a hole is ~6–12 px across, builds a
  `GrayField` and runs `shotsFromField` — all via `compute()` on a background
  isolate. Wired through `runTreffpunkt(..., targetScanner:)`.
- **Screen** (`scan_target_screen.dart`) — the Finn treff button + an analysing
  state; on result it appends deduped, capped shots and shows the hint.

## Rationale

A heuristic exploiting the known calibration ships everywhere now and needs no
dataset, where ML cannot start. Keeping the detector coordinate-free and reusing
the one calibration avoids a drift-prone second transform. The peak-contrast gate
and a generous background window remove the dominant false positive (a blob
depressing its own local mean) cheaply. Returning shots (not mutating the
session) keeps detection additive and correctable.

## Verification

### Unit
- `hole_detector_test.dart`: three dark holes on white → three centroids; a light
  hole in a large black region → found (two-sided); a thin line → rejected; a
  blob on the bull-edge band → rejected, off-band → kept; holes over a luminance
  gradient → still found; low-contrast noise → none; a hole outside the ROI →
  ignored; a hole beyond the outermost scoring ring (a miss) → ignored; the
  `maxHoles` cap; overlapping holes → one.
- `target_scan_test.dart`: `PhotoFit` letterbox round-trip with hand-computed
  values; `shotsFromField` maps a centre hole to a ten and an offset hole to the
  matching millimetres; an unusable calibration → none.
- `gray_field_test.dart`: row-major `at(x, y)` and the size assertion.

### Widget
- `scan_target_screen_test.dart`: a fake `TargetScanner` — the detect button
  appears only after calibration; detected holes are appended; the remaining
  capacity is respected; a `null` result keeps manual placement with the hint.

### Manual
Photograph a real target, align the rings, tap *Finn treff automatisk*, confirm
the markers land on the holes, adjust the misses, and commit.

## Known limitations / next increment

Assistive, not authoritative — printed numerals and odd lighting can still yield
a stray hit (delete it) or a miss (tap it). One scan fills one series. Tuning
levers left for later: morphological cleanup, a matched-filter disc score, and
per-ring radial rejection where the geometry allows. The ML route stays gated on
a labelled dataset.
