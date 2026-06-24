// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:treffpunkt/features/scoring/data/target_scanner.dart';
import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/domain/target_scan.dart';

/// A [TargetScanner] backed by the `image` package (web + Android + iOS). The
/// only file that imports `image`.
///
/// Decodes the photo, bakes its EXIF orientation (so the pixels match what
/// Flutter displays), downscales it so a bullet hole is a handful of pixels
/// across, converts it to a [GrayField] and runs the pure detector — all on a
/// background isolate via [compute], so a large photo never janks the UI. Any
/// decode/processing failure returns `null` (never throws), so auto-detect
/// degrades to manual placement (spec 0040).
class ImageTargetScanner implements TargetScanner {
  /// Creates the scanner.
  const ImageTargetScanner();

  @override
  Future<List<Shot>?> scan(
    Uint8List bytes, {
    required TargetCalibration calibration,
    required double boxSide,
    required TargetGeometry geometry,
    required int maxHoles,
  }) async {
    try {
      return await compute(
        _scanRequest,
        _ScanRequest(
          bytes: bytes,
          calibration: calibration,
          boxSide: boxSide,
          geometry: geometry,
          maxHoles: maxHoles,
        ),
      );
    } on Object catch (error) {
      if (!kReleaseMode) debugPrint('Target scan failed: $error');
      return null;
    }
  }
}

/// The arguments sent to the scan isolate (all plain, sendable data).
@immutable
class _ScanRequest {
  const _ScanRequest({
    required this.bytes,
    required this.calibration,
    required this.boxSide,
    required this.geometry,
    required this.maxHoles,
  });

  final Uint8List bytes;
  final TargetCalibration calibration;
  final double boxSide;
  final TargetGeometry geometry;
  final int maxHoles;
}

/// Longest edge (px) above which a hole becomes too large to be efficient.
const double _maxWorkingEdge = 1600;

/// Longest edge (px) below which detail is too coarse to detect holes.
const double _minWorkingEdge = 400;

/// Target hole radius (working px) the downscale aims for.
const double _targetHoleRadiusPx = 9;

/// Decodes [request]'s photo and returns the detected holes as [Shot]s, or
/// `null` when it can't be decoded. Runs on a background isolate.
List<Shot>? _scanRequest(_ScanRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);

  // Choose a working size so a hole is ~[_targetHoleRadiusPx] px across: the
  // box-space hole radius scales with the field's longest edge over the box.
  final holeRadiusBox =
      request.geometry.pelletRadiusMm * request.calibration.pixelsPerMm;
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  var workingEdge = longest.toDouble();
  if (holeRadiusBox > 0) {
    final desired = _targetHoleRadiusPx * request.boxSide / holeRadiusBox;
    workingEdge = desired.clamp(_minWorkingEdge, _maxWorkingEdge);
  }
  final landscape = oriented.width >= oriented.height;
  final edge = workingEdge.round();
  final resized = workingEdge < longest
      ? img.copyResize(
          oriented,
          width: landscape ? edge : null,
          height: landscape ? null : edge,
        )
      : oriented;

  final field = _toGrayField(resized);
  return shotsFromField(
    field,
    calibration: request.calibration,
    boxSide: request.boxSide,
    geometry: request.geometry,
    maxHoles: request.maxHoles,
  );
}

/// Converts [image] to a [GrayField] of luminance bytes.
GrayField _toGrayField(img.Image image) {
  final gray = img.grayscale(image);
  final intensities = Uint8List(gray.width * gray.height);
  var i = 0;
  for (var y = 0; y < gray.height; y++) {
    for (var x = 0; x < gray.width; x++) {
      intensities[i++] = gray.getPixel(x, y).r.toInt();
    }
  }
  return GrayField(
    width: gray.width,
    height: gray.height,
    intensities: intensities,
  );
}
