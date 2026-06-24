// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

/// A point in source-image pixel space: origin top-left, +x right, +y down.
///
/// The scan feature (spec 0039) works in the photographed image's own pixels;
/// the domain avoids `dart:ui`, so this tiny pure pair stands in for `Offset`.
@immutable
class PixelPoint {
  /// Creates a pixel point at [x] / [y].
  const PixelPoint(this.x, this.y);

  /// Horizontal pixel coordinate (left to right).
  final double x;

  /// Vertical pixel coordinate (top to bottom).
  final double y;

  /// The straight-line pixel distance to [other].
  double distanceTo(PixelPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is PixelPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Maps between a scanned photo's pixels and target millimetres (spec 0039).
///
/// A **similarity transform** — a centre, a uniform [pixelsPerMm] scale and an
/// optional rotation — is all that's needed to score a straight-on photo:
/// scoring depends only on a shot's radial distance from the centre and the
/// rings are concentric circles, so rotation never changes a score and only the
/// centre and the scale matter. An angled photo distorts the rings into an
/// ellipse the overlay can't match, prompting a retake rather than a silent
/// (and unverifiable) perspective correction. [rotationRadians] is kept for a
/// future rotation handle but is `0` today, so the overlay and the photo align
/// when the camera was held square.
class TargetCalibration {
  /// Creates a calibration centred at [centre] with the given [pixelsPerMm]
  /// scale and optional [rotationRadians] (the image's rotation relative to the
  /// target, `0` by default).
  const TargetCalibration({
    required this.centre,
    required this.pixelsPerMm,
    this.rotationRadians = 0,
  });

  /// Derives a calibration from the two calibration handles: the [centre]
  /// handle on the bull and a [scale] handle dropped on a known ring of radius
  /// [referenceRadiusMm]. The scale is the rim distance (px) over that radius.
  ///
  /// Coincident handles give a zero scale, which [isUsable] reports as unusable
  /// so the UI can keep the user adjusting before placing shots.
  factory TargetCalibration.fromHandles({
    required PixelPoint centre,
    required PixelPoint scale,
    required double referenceRadiusMm,
  }) {
    final rimPx = scale.distanceTo(centre);
    return TargetCalibration(
      centre: centre,
      pixelsPerMm: rimPx / referenceRadiusMm,
    );
  }

  /// The image-pixel coordinates of the target centre (the origin, 0 mm).
  final PixelPoint centre;

  /// The uniform scale: image pixels per target millimetre. Strictly positive
  /// for a usable calibration (see [isUsable]).
  final double pixelsPerMm;

  /// The image's rotation relative to the target, in radians. `0` in v1.
  final double rotationRadians;

  /// Whether the scale is a positive, finite number, so the transform is sound.
  bool get isUsable => pixelsPerMm.isFinite && pixelsPerMm > 0;

  /// The [Shot] (mm from the target centre) at image pixel [point].
  ///
  /// Un-translates by the [centre], scales pixels to millimetres, then rotates
  /// by `-rotationRadians` into the target's own axes.
  Shot shotFor(PixelPoint point) {
    final ux = (point.x - centre.x) / pixelsPerMm;
    final uy = (point.y - centre.y) / pixelsPerMm;
    final cos = math.cos(rotationRadians);
    final sin = math.sin(rotationRadians);
    return Shot(
      dxMm: ux * cos + uy * sin,
      dyMm: -ux * sin + uy * cos,
    );
  }

  /// The image pixel that [shot] (mm from the target centre) sits at.
  ///
  /// The inverse of [shotFor]: rotates by `+rotationRadians`, scales the
  /// millimetres to pixels, then translates to the [centre]. Used to draw the
  /// ring overlay, the placed-shot markers and the handles over the photo.
  PixelPoint imagePxFor(Shot shot) {
    final cos = math.cos(rotationRadians);
    final sin = math.sin(rotationRadians);
    final rx = shot.dxMm * cos - shot.dyMm * sin;
    final ry = shot.dxMm * sin + shot.dyMm * cos;
    return PixelPoint(
      centre.x + rx * pixelsPerMm,
      centre.y + ry * pixelsPerMm,
    );
  }
}
