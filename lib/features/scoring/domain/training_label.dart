// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/target_scan.dart';
import 'package:treffpunkt/features/scoring/domain/training_sample.dart';

/// The training-label schema version. Bump when the [buildLabel] shape changes
/// so an export pipeline can branch on it.
const int trainingLabelSchemaVersion = 1;

/// Builds the self-describing training annotation for [sample] (spec 0041),
/// given the uploaded image's [imageWidth] / [imageHeight] in pixels.
///
/// Pure: it converts the box-space calibration and holes to the **image's own
/// pixels** via [PhotoFit] (downscaling preserves the aspect ratio, so the
/// field is letterboxed exactly as the photo), so the label is reproducible
/// from the uploaded JPEG alone — independent of the phone screen. The image
/// bytes never appear here; only positions and the target geometry do.
Map<String, dynamic> buildLabel(
  TrainingSample sample, {
  required int imageWidth,
  required int imageHeight,
}) {
  final fit = PhotoFit(
    fieldWidth: imageWidth,
    fieldHeight: imageHeight,
    boxSide: sample.boxSide,
  );
  final centre = fit.toField(sample.calibration.centre);
  final pixelsPerMm = sample.calibration.pixelsPerMm / fit.scale;
  final geometry = sample.geometry;

  return <String, dynamic>{
    'schemaVersion': trainingLabelSchemaVersion,
    'sampleId': sample.id,
    'capturedAt': sample.capturedAt.toUtc().toIso8601String(),
    'appVersion': sample.appVersion,
    'image': <String, dynamic>{
      'widthPx': imageWidth,
      'heightPx': imageHeight,
    },
    'geometry': <String, dynamic>{
      'name': geometry.name,
      'caliberMm': geometry.caliberMm,
      'ringOuterDiametersMm': geometry.ringOuterDiametersMm,
      'blackBullDiameterMm': geometry.blackBullDiameterMm,
      'innerTenDiameterMm': geometry.innerTenDiameterMm,
      'lowestRingValue': geometry.lowestRingValue,
    },
    'calibration': <String, dynamic>{
      'centrePx': <String, double>{'x': centre.x, 'y': centre.y},
      'pixelsPerMm': pixelsPerMm,
      'rotationRadians': sample.calibration.rotationRadians,
    },
    'holes': <Map<String, dynamic>>[
      for (final hole in sample.holes)
        () {
          final imagePx = fit.toField(
            sample.calibration.imagePxFor(hole.shot),
          );
          return <String, dynamic>{
            'xPx': imagePx.x,
            'yPx': imagePx.y,
            'dxMm': hole.shot.dxMm,
            'dyMm': hole.shot.dyMm,
            'source': hole.source.name,
            'edited': hole.edited,
          };
        }(),
    ],
  };
}
