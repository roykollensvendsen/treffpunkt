// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Where a labelled hole came from (spec 0041): the auto-detector or a manual
/// tap. Lets a training corpus also grade the detector against human truth.
enum TrainingHoleSource {
  /// Placed by the heuristic auto-detector (spec 0040).
  auto,

  /// Placed by a manual tap on the photo.
  manual,
}

/// One labelled hole in a [TrainingSample]: a [shot] (mm from the target
/// centre), its [source], and whether it was [edited] (dragged) once placed.
class TrainingHole {
  /// Creates a labelled hole.
  const TrainingHole({
    required this.shot,
    required this.source,
    this.edited = false,
  });

  /// The hole position in millimetres from the target centre.
  final Shot shot;

  /// Whether the auto-detector or a manual tap placed it.
  final TrainingHoleSource source;

  /// Whether it was dragged to adjust after it was first placed.
  final bool edited;
}

/// A consented training sample captured when a shooter confirms a target scan
/// (spec 0041): the photo plus the human-confirmed hit labels.
///
/// The [calibration] and [boxSide] are in the scan screen's **box** space; the
/// label builder converts the holes and the calibration to the uploaded image's
/// own pixels. [imageBytes] is transport only — it never appears in the label
/// JSON.
class TrainingSample {
  /// Creates a sample.
  const TrainingSample({
    required this.id,
    required this.imageBytes,
    required this.geometry,
    required this.calibration,
    required this.boxSide,
    required this.holes,
    required this.capturedAt,
    required this.appVersion,
  });

  /// The stable client-generated id; also the Storage object name stem.
  final String id;

  /// The captured photo bytes (JPEG), re-encoded to strip EXIF before upload.
  final Uint8List imageBytes;

  /// The target the holes are scored against.
  final TargetGeometry geometry;

  /// The shooter's calibration, in box (screen) space.
  final TargetCalibration calibration;

  /// The square photo box side (logical px) the calibration is expressed in.
  final double boxSide;

  /// The confirmed holes, in firing/placement order.
  final List<TrainingHole> holes;

  /// When the scan was confirmed.
  final DateTime capturedAt;

  /// The app build label at capture time.
  final String appVersion;
}
