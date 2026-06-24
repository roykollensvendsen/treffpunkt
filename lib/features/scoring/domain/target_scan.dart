// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/hole_detector.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// How a [GrayField] (possibly downscaled) is laid out inside the square photo
/// box of the scan screen, via `BoxFit.contain` (spec 0040).
///
/// Downscaling preserves the aspect ratio, so the field is letterboxed in the
/// box exactly as the displayed photo is — no original-resolution bookkeeping
/// is needed. A field point maps to a box point by `point * scale + offset`.
class PhotoFit {
  /// Creates the fit for a [fieldWidth] × [fieldHeight] field in a square box
  /// of side [boxSide].
  factory PhotoFit({
    required int fieldWidth,
    required int fieldHeight,
    required double boxSide,
  }) {
    final scale = math.min(boxSide / fieldWidth, boxSide / fieldHeight);
    return PhotoFit._(
      scale: scale,
      offsetX: (boxSide - fieldWidth * scale) / 2,
      offsetY: (boxSide - fieldHeight * scale) / 2,
    );
  }

  const PhotoFit._({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  /// Field pixels per box pixel (the `BoxFit.contain` scale).
  final double scale;

  /// Horizontal letterbox offset (box pixels).
  final double offsetX;

  /// Vertical letterbox offset (box pixels).
  final double offsetY;

  /// The box-space point for a [field] point.
  PixelPoint toBox(PixelPoint field) =>
      PixelPoint(field.x * scale + offsetX, field.y * scale + offsetY);

  /// The field-space point for a [box] point.
  PixelPoint toField(PixelPoint box) =>
      PixelPoint((box.x - offsetX) / scale, (box.y - offsetY) / scale);
}

/// Detects bullet holes in [field] and returns them as [Shot]s, given the
/// box-space [calibration] the shooter set, the photo box side [boxSide], the
/// target [geometry] and the cap [maxHoles] (spec 0040).
///
/// Pure glue between the coordinate-free [HoleDetector] and the app's mm space:
/// it derives the field-space centre and scale for the detector, runs it, then
/// lifts each centroid back to box space and reuses the **existing**
/// [TargetCalibration.shotFor] — one calibration as the single source of truth,
/// so a seeded marker lands exactly where a manual tap there would.
List<Shot> shotsFromField(
  GrayField field, {
  required TargetCalibration calibration,
  required double boxSide,
  required TargetGeometry geometry,
  required int maxHoles,
  HoleDetector detector = const HoleDetector(),
}) {
  if (maxHoles <= 0 || !calibration.isUsable) return <Shot>[];
  final fit = PhotoFit(
    fieldWidth: field.width,
    fieldHeight: field.height,
    boxSide: boxSide,
  );
  final centreField = fit.toField(calibration.centre);
  final pixelsPerMmField = calibration.pixelsPerMm / fit.scale;
  final centroids = detector.detect(
    field,
    centre: centreField,
    pixelsPerMm: pixelsPerMmField,
    geometry: geometry,
    maxHoles: maxHoles,
  );
  return <Shot>[
    for (final centroid in centroids) calibration.shotFor(fit.toBox(centroid)),
  ];
}
