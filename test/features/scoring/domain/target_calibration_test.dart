// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the photo-pixel <-> target-millimetre transform behind the
// "Skann skive" camera scan (spec 0039): a similarity transform parameterised
// by a centre and a uniform scale, with the two calibration handles deriving
// the scale from a known ring radius.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';

void main() {
  group('TargetCalibration.shotFor', () {
    test('the centre pixel maps to the target origin', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(120, 80),
        pixelsPerMm: 4,
      );
      final shot = calibration.shotFor(const PixelPoint(120, 80));
      expect(shot.dxMm, closeTo(0, 1e-9));
      expect(shot.dyMm, closeTo(0, 1e-9));
    });

    test('a pixel offset divides by the scale to millimetres', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(100, 100),
        pixelsPerMm: 5,
      );
      // 50 px right and 20 px down at 5 px/mm is 10 mm right, 4 mm down.
      final shot = calibration.shotFor(const PixelPoint(150, 120));
      expect(shot.dxMm, closeTo(10, 1e-9));
      expect(shot.dyMm, closeTo(4, 1e-9));
    });
  });

  group('TargetCalibration.imagePxFor', () {
    test('the origin maps back to the centre pixel', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(60, 40),
        pixelsPerMm: 3,
      );
      final px = calibration.imagePxFor(const Shot(dxMm: 0, dyMm: 0));
      expect(px.x, closeTo(60, 1e-9));
      expect(px.y, closeTo(40, 1e-9));
    });

    test('round-trips with shotFor', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(200, 150),
        pixelsPerMm: 6.5,
      );
      const original = PixelPoint(275, 90);
      final back = calibration.imagePxFor(calibration.shotFor(original));
      expect(back.x, closeTo(original.x, 1e-9));
      expect(back.y, closeTo(original.y, 1e-9));
    });
  });

  group('TargetCalibration.fromHandles', () {
    test('derives the scale from a rim handle on a known ring', () {
      // A rim handle 80 px from the centre on a 20 mm ring is 4 px/mm.
      final calibration = TargetCalibration.fromHandles(
        centre: const PixelPoint(100, 100),
        scale: const PixelPoint(180, 100),
        referenceRadiusMm: 20,
      );
      expect(calibration.centre.x, 100);
      expect(calibration.pixelsPerMm, closeTo(4, 1e-9));
      // A tap on that rim handle therefore scores exactly the ring radius out.
      final shot = calibration.shotFor(const PixelPoint(180, 100));
      expect(shot.distanceMm, closeTo(20, 1e-9));
    });

    test('uses the diagonal distance for an off-axis rim handle', () {
      // 30 px right, 40 px down is 50 px; on a 25 mm ring that is 2 px/mm.
      final calibration = TargetCalibration.fromHandles(
        centre: const PixelPoint(0, 0),
        scale: const PixelPoint(30, 40),
        referenceRadiusMm: 25,
      );
      expect(calibration.pixelsPerMm, closeTo(2, 1e-9));
    });
  });

  group('TargetCalibration.isUsable', () {
    test('is true for a positive finite scale', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(0, 0),
        pixelsPerMm: 4,
      );
      expect(calibration.isUsable, isTrue);
    });

    test('is false when the two handles coincide (zero scale)', () {
      final calibration = TargetCalibration.fromHandles(
        centre: const PixelPoint(50, 50),
        scale: const PixelPoint(50, 50),
        referenceRadiusMm: 20,
      );
      expect(calibration.pixelsPerMm, 0);
      expect(calibration.isUsable, isFalse);
    });
  });

  group('rotation', () {
    test('a quarter turn rotates the mapped millimetres', () {
      const calibration = TargetCalibration(
        centre: PixelPoint(0, 0),
        pixelsPerMm: 1,
        rotationRadians: math.pi / 2,
      );
      // With a +90° image rotation, a point 10 px to the right reads as 10 mm
      // "up" the rotated target axis; distance is preserved either way.
      final shot = calibration.shotFor(const PixelPoint(10, 0));
      expect(shot.distanceMm, closeTo(10, 1e-9));
      expect(shot.dxMm, closeTo(0, 1e-9));
      expect(shot.dyMm, closeTo(-10, 1e-9));
    });
  });
}
