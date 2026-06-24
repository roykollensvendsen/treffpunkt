<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0021: Camera target scan — similarity-transform calibration + an image-source seam

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

The NSF domain expert asked to **photograph the paper target and have the app
determine the hit points** (spec 0039). The state of the art splits the problem
into *calibration / perspective correction* and *hole detection*. Robust
automatic hole detection wants a model trained on a labelled NSF-target dataset
(~96% with a tuned YOLO model; ~80% with classical OpenCV, which struggles with
overlapping holes, torn paper and printed numerals) — and that dataset does not
exist yet, so it is weeks of data work before any accuracy. The app also deploys
as web (GitHub Pages) and runs on mobile, and must keep its lean-dependency,
pure-Dart-domain, strict-quality-gate discipline.

Two decisions follow: **how the photo maps to target millimetres**, and **how the
camera is reached** without coupling the app to a plugin or breaking tests.

## Decision

- **Ship manual-assisted first.** v1 supplies the calibration and the scoring;
  the shooter supplies the photo and taps each hole. This is the robust
  manual-correction fallback every serious app keeps (e.g. TargetScan's "swipe to
  reposition the ring"), works identically on web and mobile, and is exactly the
  layer automatic detection later pre-fills.
- **Calibrate with a similarity transform, not a homography.** Scoring depends
  only on a shot's **radial** distance from the centre (`Shot.distanceMm`) and the
  rings are concentric circles, so a rotation never changes a score; a straight-on
  photo needs only a **centre** and a **uniform scale**. The pure-Dart
  `TargetCalibration` (centre, `pixelsPerMm`, `rotationRadians`) is parameterised
  by two draggable handles — a centre handle on the bull and a scale handle on the
  outer ring, whose rim distance over `geometry.maxScoringRadiusMm` fixes the
  scale. The full ring overlay is drawn through the transform, so an **angled
  photo** (rings → ellipse) visibly fails to line up and the shooter retakes —
  preferred over a homography the shooter cannot sanity-check. `rotationRadians`
  is carried but `0` in v1 (a rotation handle can be added with no data
  migration). The domain avoids `dart:ui`, so a tiny pure `PixelPoint` stands in
  for `Offset`.
- **Reach the camera through an `ImageSourceService` seam** — a fresh instance of
  the ADR-0015 pattern. `capturePhoto()` / `pickFromGallery()` report a sealed
  `ImageSourceResult` (`ImagePicked` / `ImagePickCancelled` / `ImagePickDenied` /
  `ImagePickUnavailable`) and **never throw**, so the screen degrades cleanly. The
  default `UnavailableImageSourceService` keeps the feature inert in tests and on
  unwired platforms; the real `ImagePickerImageSourceService` is the **only** file
  importing `image_picker` and sits over an `ImagePickerGateway` so the
  cancel/denial/error mapping is unit-tested with a fake. Wired as the real
  default through `runTreffpunkt(..., imageSourceService:)`.
- **Commit by returning shots, not by mutating the session.** The scan screen
  takes the target `geometry` and the series' remaining capacity and **pops a
  `List<Shot>`**; the series screen appends them via a new
  `SessionNotifier.placeShots`, which persists once and never seals. So live
  re-scoring and drag-adjust happen on the photo before the persisted series
  changes, and the commit runs in the series screen's own provider scope (a pushed
  route is outside the screen's scoped `sessionProvider`).

## Consequences

- The calibration maths, the image-source mapping and the commit semantics are
  all unit-/widget-testable with fakes — no real camera, no plugin channels, no
  ML in tests; the domain stays pure Dart.
- `image_picker` is the one new runtime dependency, confined behind the seam in a
  single file. **Native permission wiring lands with the feature** (mirroring
  ADR-0015): Android `AndroidManifest.xml` and iOS `Info.plist` camera /
  photo-library usage strings; on web `ImageSource.camera` is best-effort and the
  plugin falls back to a file dialog, so the gallery path is always offered.
- Correct scores require a roughly straight-on photo; angled shots are handled by
  retake, not correction. Using the outermost ring as the scale reference keeps
  the relative scale error smallest.

## Alternatives considered

- **Automatic hole detection in v1 (classical CV or trained ML):** deferred — ML
  needs a labelled NSF-target dataset that does not exist yet and is native-only
  inference; classical OpenCV is ~80% and fragile. Both still need the manual
  calibration + correction UI this ADR builds, so it lands first and detection
  becomes its pre-fill sequel.
- **A full homography (4-corner perspective correction):** rejected for v1 — the
  gesture is harder (four accurate correspondences) and the correction is
  unverifiable by the shooter; the similarity transform plus a visible overlay is
  simpler and self-checking for straight-on photos.
- **A live camera preview (`camera` package) instead of `image_picker`:**
  rejected — heavier, no gallery, no web file input; overkill for photographing a
  static target.
- **Mutating `sessionProvider` directly from the scan screen:** rejected — a
  pushed route is outside the series screen's scoped provider, and per-tap commits
  would persist mid-scan and could trip completion; returning a `List<Shot>` is
  cleaner and keeps the scan self-contained.
