// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Draws the target ring overlay and the tapped shot markers over a scanned
/// photo (spec 0039), mapped through a [TargetCalibration].
///
/// Strokes only — no opaque fill — so the photographed target shows through and
/// the user can see whether the overlay lines up (an angled photo won't). The
/// rings come from [geometry]; each is a circle about the calibration centre
/// with radius `ringRadiusMm * pixelsPerMm`. Markers sit where each tapped shot
/// maps back to via [TargetCalibration.imagePxFor]. The draggable calibration
/// handles are real widgets in the screen, not painted here.
class ScanOverlayPainter extends CustomPainter {
  /// Creates an overlay for [geometry] under [calibration], marking [shots].
  const ScanOverlayPainter({
    required this.geometry,
    required this.calibration,
    required this.shots,
  });

  /// The target whose rings are drawn.
  final TargetGeometry geometry;

  /// The photo-pixel ↔ millimetre transform the overlay is drawn through.
  final TargetCalibration calibration;

  /// The candidate shots placed so far, in tap order.
  final List<Shot> shots;

  /// The calibration centre as a pixel [Offset].
  ///
  /// Exposed so the overlay geometry is unit-testable without rendering.
  Offset get centreOffset => Offset(calibration.centre.x, calibration.centre.y);

  /// The on-screen pixel radius of [ring]'s outer edge under the calibration.
  double ringRadiusPx(int ring) =>
      geometry.outerDiameterMm(ring) / 2 * calibration.pixelsPerMm;

  /// The pixel centres of the shot markers, in tap order.
  List<Offset> get markerCentres => <Offset>[
    for (final shot in shots)
      Offset(
        calibration.imagePxFor(shot).x,
        calibration.imagePxFor(shot).y,
      ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!calibration.isUsable) return;
    final centre = centreOffset;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.85);

    for (
      var ring = geometry.lowestRingValue;
      ring <= geometry.highestRing;
      ring++
    ) {
      canvas.drawCircle(centre, ringRadiusPx(ring), ringPaint);
    }

    final markerRadius = geometry.pelletRadiusMm * calibration.pixelsPerMm;
    for (final markerCentre in markerCentres) {
      canvas
        ..drawCircle(
          markerCentre,
          markerRadius,
          Paint()..color = Colors.amber.withValues(alpha: 0.9),
        )
        ..drawCircle(
          markerCentre,
          markerRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black,
        );
    }
  }

  @override
  bool shouldRepaint(ScanOverlayPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.calibration.centre != calibration.centre ||
      oldDelegate.calibration.pixelsPerMm != calibration.pixelsPerMm ||
      oldDelegate.calibration.rotationRadians != calibration.rotationRadians ||
      !listEquals(oldDelegate.shots, shots);
}
