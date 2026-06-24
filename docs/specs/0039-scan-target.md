<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0039 — Skann skive (camera-assisted shot placement)

- **Status:** Accepted
- **Related:** spec 0001/0004 (target geometry & scoring), spec 0006 (the live
  tap-to-place target), ADR-0015 (platform service behind an interface),
  ADR-0021 (this feature's calibration model + image-source seam)

## Context

A shooter records a session by tapping each shot onto the on-screen target (spec
0006). The NSF domain expert asked to instead **photograph the paper target and
have the app determine the treffpunkter (hit points)**. Robust *automatic* hole
detection needs a trained model on a labelled NSF-target dataset that does not
exist yet, so v1 is **manual-assisted**: the app supplies the calibration and the
scoring, the shooter supplies the photo and the taps. It ships on web and mobile
from one codebase and is the manual-correction foundation any later
auto-detection (ADR-0021's sequel) pre-fills.

The whole feature reduces to **"produce `Shot(dxMm, dyMm)` from a photo"**: a
`Shot` is purely a position from the target centre, and `ScoringService`, the
drag-to-adjust gesture and series sealing are all reused unchanged.

## Requirements

1. **Capture a photo.** From the series screen, a "Skann skive" action opens a
   scan screen offering *take a photo* (camera) and *choose a photo* (gallery /
   file). Both reach the device through a service seam and **never throw**: a
   cancel, a permission denial or no source keeps the shooter on the capture step
   with a hint (denial suggests the gallery, which needs no camera permission).
2. **Calibrate.** The scan screen overlays the active target's ring set on the
   photo. The shooter drags two handles — a **centre** handle onto the bull and a
   **scale** handle onto the outermost ring — to align the overlay; this fixes a
   photo-pixel → millimetre transform. Placement is blocked until the calibration
   is usable (the two handles are not coincident).
3. **Place shots.** In placement mode, each tap on the photo becomes a `Shot`,
   scored live (the most recent shot's ring is shown), and a long-press on a
   marker picks it up to drag. An *undo* removes the last shot. Taps outside the
   rings are allowed and score 0 (a real miss).
4. **Respect capacity.** At most the current series' *remaining* shots may be
   placed; further taps are rejected with a hint.
5. **Commit.** *Bruk skudd* returns the placed shots to the series screen, which
   appends them to the current series. The scan **never seals** the series —
   sealing stays the existing manual gesture, so a scan that fills the series
   behaves exactly like tapping the last shot by hand.
6. **No regression.** Tapping the live target (spec 0006) is unchanged; the scan
   is an alternative way to fill the same series.

## Design

- **Calibration — a pure-Dart similarity transform**
  (`lib/features/scoring/domain/target_calibration.dart`): `PixelPoint(x, y)` and
  `TargetCalibration(centre, pixelsPerMm, rotationRadians = 0)` with
  `shotFor(PixelPoint) → Shot` and `imagePxFor(Shot) → PixelPoint`. A
  `fromHandles` factory derives `pixelsPerMm` from the rim distance over the
  outer ring's known radius (`geometry.maxScoringRadiusMm`). Rotation is `0` in
  v1 (see Rationale). Unit-tested.
- **Image source — a seam (ADR-0015 / ADR-0021)**:
  `ImageSourceService` (`data/image_source_service.dart`) with a sealed
  `ImageSourceResult` (`ImagePicked` / `ImagePickCancelled` / `ImagePickDenied` /
  `ImagePickUnavailable`); the default `UnavailableImageSourceService`; and the
  real `ImagePickerImageSourceService` (`data/image_picker_image_source_service.dart`,
  the only file importing `image_picker`) over an `ImagePickerGateway` so the
  cancel/denial/error mapping is unit-tested with a fake. Wired through
  `runTreffpunkt(..., imageSourceService:)` and `imageSourceServiceProvider`.
- **Commit — `SessionNotifier.placeShots(List<Shot>)`**: appends in order,
  stopping at capacity, persists once, and never seals/advances.
- **Screen** (`presentation/scan_target_screen.dart`): a `ConsumerStatefulWidget`
  with `capture → calibrate → place` steps; the overlay
  (`presentation/scan_overlay_painter.dart`) draws the rings and markers through
  the calibration over the photo (stroke-only, so the target shows through). It
  takes the `geometry` and `maxShots` and pops a `List<Shot>`, so it is
  self-contained and testable with a fake image source — independent of the
  series screen's scoped providers.

## Rationale

Scoring depends only on a shot's **radial** distance from the centre, and the
rings are concentric circles, so a rotation never changes a score and a
straight-on photo needs only a centre and a uniform scale — a similarity
transform, not a homography. An angled photo distorts the rings into an ellipse
the overlay visibly fails to match, prompting a retake, which is a better, more
honest v1 than a perspective correction the shooter cannot sanity-check. Keeping
the scan self-contained (it returns shots rather than mutating the session) means
live re-scoring and drag-adjust happen on the photo before anything touches the
persisted series, and the commit runs in the series screen's own provider scope.
`image_picker` is the one new dependency — one package covering camera + gallery
on mobile and a file dialog on web — confined behind the seam.

## Verification

### Unit
- `target_calibration_test.dart`: centre → `(0,0)`; an outer-ring pixel → the
  ring radius in mm; `shotFor`/`imagePxFor` round-trip; `fromHandles` scale;
  coincident handles → not usable; the rotation case.
- `image_picker_image_source_service_test.dart`: a fake gateway drives
  picked / cancelled / denied / error → the four `ImageSourceResult`s.
- `session_providers_test.dart`: `placeShots` appends all shots, caps at
  capacity, never auto-advances, and appends after existing shots.
- `scan_overlay_painter_test.dart`: ring radii and marker pixels through a known
  calibration.

### Widget
- `scan_target_screen_test.dart`: a fake image source drives capture → calibrate
  → place; a centre tap scores 10 and a far tap scores 0; placement is capped at
  the remaining capacity; confirming pops the placed shots.
- `series_screen_test.dart`: the "Skann skive" action runs the whole flow and the
  committed shot lands in the series total.

### Manual
Open a session, tap "Skann skive", take or choose a target photo, drag the two
handles until the overlay rings line up, tap each hole, and confirm — the shots
appear in the series, scored, ready to seal.

## Known limitations / next increment

Manual-assisted only: no automatic hole detection yet (ADR-0021's sequel —
classical CV or a trained model that pre-fills the taps). One scan fills one
series (no multi-series-per-card). Angled photos are handled by retake, not
perspective correction. `rotationRadians` is carried but always 0 (a rotation
handle can be added without a data migration).
