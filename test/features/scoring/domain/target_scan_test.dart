// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the scan coordinate mapping (spec 0040): the BoxFit.contain
// letterbox round-trips, and shotsFromField turns detected blobs into Shots in
// the target's millimetre space (a centre hole scores a ten).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/domain/target_scan.dart';

GrayField _fieldWithDiscs(
  int size,
  List<(double, double)> centres, {
  double r = 6,
}) {
  final px = Uint8List(size * size)..fillRange(0, size * size, 220);
  for (final (cx, cy) in centres) {
    final r2 = r * r;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r2) px[y * size + x] = 30;
      }
    }
  }
  return GrayField(width: size, height: size, intensities: px);
}

void main() {
  group('PhotoFit', () {
    test('letterboxes a wide field and round-trips', () {
      final fit = PhotoFit(fieldWidth: 200, fieldHeight: 100, boxSide: 400);
      expect(fit.scale, 2);
      expect(fit.offsetX, 0);
      expect(fit.offsetY, 100); // (400 - 100*2)/2

      final box = fit.toBox(const PixelPoint(10, 20));
      expect(box.x, 20);
      expect(box.y, 140);

      final back = fit.toField(box);
      expect(back.x, closeTo(10, 1e-9));
      expect(back.y, closeTo(20, 1e-9));
    });
  });

  group('shotsFromField', () {
    const geometry = TargetGeometry.airRifle10m();
    const scoring = ScoringService();
    // boxSide == field size, so field pixels are box pixels (scale 1).
    const calibration = TargetCalibration(
      centre: PixelPoint(120, 120),
      pixelsPerMm: 2.667,
    );

    test('a centre hole becomes a ten', () {
      final field = _fieldWithDiscs(240, <(double, double)>[(120, 120)]);

      final shots = shotsFromField(
        field,
        calibration: calibration,
        boxSide: 240,
        geometry: geometry,
        maxHoles: 10,
      );

      expect(shots, hasLength(1));
      expect(scoring.integerScore(geometry, shots.single), 10);
      expect(shots.single.distanceMm, closeTo(0, 0.6));
    });

    test('an offset hole maps to the matching millimetres', () {
      // 27 px right of centre at 2.667 px/mm ≈ 10.1 mm.
      final field = _fieldWithDiscs(240, <(double, double)>[(147, 120)]);

      final shots = shotsFromField(
        field,
        calibration: calibration,
        boxSide: 240,
        geometry: geometry,
        maxHoles: 10,
      );

      expect(shots, hasLength(1));
      expect(shots.single.dxMm, closeTo(10.1, 0.8));
      expect(shots.single.dyMm, closeTo(0, 0.8));
    });

    test('returns nothing when the calibration is unusable', () {
      final field = _fieldWithDiscs(240, <(double, double)>[(120, 120)]);

      final shots = shotsFromField(
        field,
        calibration: const TargetCalibration(
          centre: PixelPoint(120, 120),
          pixelsPerMm: 0, // coincident handles
        ),
        boxSide: 240,
        geometry: geometry,
        maxHoles: 10,
      );

      expect(shots, isEmpty);
    });
  });
}
