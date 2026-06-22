// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Geometry-locking vector tests for the ISSF 50 m rifle face (spec 0017).
//
// These mirror spec 0001 / 0005: a table of representative shot offsets (mm
// from centre) -> expected ring, including both sides of each ring boundary and
// the inner-ten edge. They pin the existing geometry so it cannot drift; they
// do not change it. Boundary offsets are nudged by 0.01 mm off the exact
// scoring radius to avoid floating-point ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();

  group('50 m rifle face (.22, rings 1-10)', () {
    const geometry = TargetGeometry.smallbore50m();
    int score(double d) =>
        scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
    bool innerTen(double d) =>
        scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

    test('geometry numbers match the ISSF 50 m rifle face', () {
      expect(geometry.name, '50 m Rifle');
      expect(geometry.caliberMm, 5.6); // .22 LR
      expect(geometry.pelletRadiusMm, closeTo(2.8, 1e-9));
      expect(geometry.lowestRingValue, 1);
      expect(geometry.highestRing, 10);
      // ringOuterDiametersMm is ordered outermost (ring 1) -> innermost
      // (ring 10): outerDiameterMm(ring) == ringOuterDiametersMm[ring - 1].
      expect(geometry.outerDiameterMm(1), 154.4); // outermost
      expect(geometry.outerDiameterMm(10), 10.4); // innermost
      expect(geometry.outerDiameterMm(9), 26.4);
      expect(geometry.outerDiameterMm(4), 106.4);
      expect(geometry.hasUniformRings, isTrue); // uniform 16 mm diameter step
      expect(geometry.blackBullDiameterMm, 112.4);
      expect(geometry.innerTenDiameterMm, 5);
      expect(geometry.innerTenScoringRadiusMm, closeTo(5.3, 1e-9));
    });

    // Centre-distance scoring thresholds (.22, pellet radius 2.8 mm), an even
    // 8 mm grid: ring 10 -> 8.0, 9 -> 16.0, 8 -> 24.0, 7 -> 32.0, 6 -> 40.0,
    // 5 -> 48.0, 4 -> 56.0, 3 -> 64.0, 2 -> 72.0, 1 -> 80.0 mm.
    test('integer score across every ring, both sides of the boundary', () {
      const vectors = <(double, int)>[
        (0, 10),
        (7.99, 10),
        (8.01, 9),
        (15.99, 9),
        (16.01, 8),
        (24.01, 7),
        (32.01, 6),
        (40.01, 5),
        (48.01, 4),
        (56.01, 3),
        (64.01, 2),
        (72.01, 1),
        (79.99, 1),
        (80.01, 0), // just past the 1-ring is a miss
        (100, 0),
      ];
      for (final (d, ring) in vectors) {
        expect(score(d), ring, reason: 'd=$d mm should score $ring');
      }
    });

    test('inner ten on either side of the 5 mm ring', () {
      expect(innerTen(5.29), isTrue); // inside the 5.3 mm scoring radius
      expect(innerTen(5.31), isFalse); // outside -> a plain ten
      expect(score(5.31), 10); // still a ten, just not an inner ten
    });

    test('distance is radial, not per-axis, and sign-independent', () {
      // (-5, 5) has d = sqrt(50) ~= 7.07 mm: inside the 8.0 ten radius, so a
      // ten regardless of the negative axis and the two non-zero components.
      expect(scoring.integerScore(geometry, const Shot(dxMm: -5, dyMm: 5)), 10);
      // (-12, 12) has d = sqrt(288) ~= 16.97 mm: past the 16.0 ten/nine edge,
      // so an eight, proving the score uses the radial distance not an axis.
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -12, dyMm: 12)),
        8,
      );
    });
  });
}
