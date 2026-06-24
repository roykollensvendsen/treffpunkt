<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0022: Auto-detect holes with a pure-Dart heuristic, not ML

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

Spec 0039 shipped manual-assisted scanning; ADR-0021 named automatic hole
detection as the sequel and weighed two roads. The high-accuracy road is a
trained model (~96%), but it needs a **labelled dataset of NSF-target photos that
does not exist yet** (weeks of collecting + labelling + training), ships a ~22 MB
model and runs **native-only** — it would not work in the web app, which is the
live deployment. Classical OpenCV via FFI is also native-only. The app must keep
its lean-dependency, pure-Dart-domain, strict-quality-gate discipline, and detect
on **web + mobile from one codebase**.

The shooter has already **calibrated** the photo, so the detector knows the
centre, the scale (hence the expected hole size in pixels) and every printed ring
/ bull radius — strong priors a generic detector lacks.

## Decision

- **Detect with a pure-Dart heuristic, not ML.** It runs everywhere, needs no
  dataset, and the whole detector is unit-testable in plain Dart. Accuracy is
  lower (~70–80% on good photos) but the feature is **assistive** — it pre-fills
  editable shots the shooter reviews — so it is tuned to favour **false negatives
  over false positives** (a missed hole is one tap; a phantom must be spotted and
  deleted).
- **Algorithm** (`HoleDetector`, all O(W·H)): a **two-sided local-contrast mask**
  via an integral image (a hole is dark-on-white paper *or* light-on-black bull;
  deviation from the *local* mean catches both and absorbs lighting gradients),
  with a **peak-contrast gate** that removes the dominant false positive — the
  faint "halo" where a blob depresses its own local mean. **Connected components**
  are filtered by area, **compactness** and aspect (rejecting thin ring lines) and
  by a thin **radial band at the bull edge**; survivors are de-duplicated and
  ranked by strength. Per-ring radial rejection is deliberately *not* used: the
  inner rings are too densely spaced, so it would reject real holes — the shape
  filter handles ring lines instead.
- **Keep the detector coordinate-free** and reuse the **one** calibration. The
  detector returns centroids in field pixels; `shotsFromField` maps them to `Shot`
  via `BoxFit.contain` of the field into the box (`PhotoFit`) and the existing
  `TargetCalibration.shotFor`. Because downscaling preserves aspect ratio, the
  field is letterboxed exactly as the displayed photo — no original-resolution
  bookkeeping, and no drift-prone second calibration.
- **Isolate the `image` dependency behind a `TargetScanner` seam** (the
  ADR-0015 pattern): `scan(...) → Future<List<Shot>?>`, never throws (null =
  couldn't process, empty = none found). The real `ImageTargetScanner` is the
  only file importing `image`; it decodes, bakes EXIF orientation (so pixels match
  what Flutter shows), downscales so a hole is ~6–12 px across, and runs on a
  **background isolate** (`compute`) so a large photo never janks the UI.
- **Detection is additive.** It returns shots the screen appends (deduped, capped
  at remaining capacity) and never seals — a decode failure or zero hits degrades
  to exactly the manual flow.

## Consequences

- Auto-detect ships on web + mobile today, with no dataset and one new pure-Dart
  dependency (`image`) confined to one file.
- The detector, the coordinate maths and the seam are all unit-/widget-testable
  with synthetic fields and a fake scanner — no ML, no real decode in tests.
- Accuracy is heuristic and varies with photo quality; the UI and docs frame it
  as assistive, and every hit stays correctable.
- A future ML detector can slot in behind the same `TargetScanner` seam once a
  dataset exists, reusing the calibration and the review UI as its
  manual-correction fallback.

## Alternatives considered

- **Trained ML (YOLO/TFLite) now:** rejected — no dataset exists, ~22 MB model,
  native-only (breaks web). It is the eventual high-accuracy road, gated on data.
- **Classical OpenCV via FFI:** rejected — native-only and fragile, and still
  needs the calibration + correction UI this builds.
- **Per-ring radial rejection:** rejected for the inner rings — too densely
  spaced; it removes real holes. Only the bull-edge band is used.
- **Building a second, image-space calibration:** rejected — duplicating the
  centre/scale invites drift; lifting centroids into the existing calibration is
  one source of truth.
