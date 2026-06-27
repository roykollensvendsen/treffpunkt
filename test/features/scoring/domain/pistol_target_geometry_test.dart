// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Geometry-locking vector tests for the 25 m pistol faces (spec 0005).
//
// These mirror spec 0001's shape: a table of representative shot offsets (mm
// from centre) -> expected ring, for both the precision (rings 1-10) and rapid
// (rings 5-10) faces, including inner-ten boundary cases and a centre-fire
// gauge-edge case. They pin the existing geometry so it cannot drift; they do
// not change it. Boundary offsets are nudged by 0.01 mm off the exact scoring
// radius to avoid floating-point ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();

  group('25 m pistol — precision face (.22, rings 1-10)', () {
    const geometry = TargetGeometry.pistol25mPrecision();
    int score(double d) =>
        scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
    bool innerTen(double d) =>
        scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

    test('geometry numbers match the ISSF precision face', () {
      expect(geometry.caliberMm, 5.6); // .22 LR
      expect(geometry.pelletRadiusMm, closeTo(2.8, 1e-9));
      expect(geometry.lowestRingValue, 1);
      expect(geometry.highestRing, 10);
      expect(geometry.outerDiameterMm(10), 50);
      expect(geometry.outerDiameterMm(9), 100);
      expect(geometry.outerDiameterMm(1), 500);
      expect(geometry.blackBullDiameterMm, 200);
      expect(geometry.innerTenDiameterMm, 25);
      expect(geometry.innerTenScoringRadiusMm, closeTo(15.3, 1e-9));
    });

    // Centre-distance scoring thresholds (.22, pellet radius 2.8 mm):
    // ring 10 -> 27.8, 9 -> 52.8, 8 -> 77.8, 7 -> 102.8, 6 -> 127.8,
    // 5 -> 152.8, 4 -> 177.8, 3 -> 202.8, 2 -> 227.8, 1 -> 252.8 mm.
    test('integer score across every ring', () {
      const vectors = <(double, int)>[
        (0, 10),
        (27.79, 10),
        (27.81, 9),
        (52.79, 9),
        (52.81, 8),
        (77.81, 7),
        (102.81, 6),
        (127.81, 5),
        (152.81, 4),
        (177.81, 3),
        (202.81, 2),
        (227.81, 1),
        (252.79, 1),
        (252.81, 0), // just past the 1-ring is a miss
        (300, 0),
      ];
      for (final (d, ring) in vectors) {
        expect(score(d), ring, reason: 'd=$d mm should score $ring');
      }
    });

    test('inner ten on either side of the 25 mm ring', () {
      expect(innerTen(15.29), isTrue); // inside the 15.3 mm scoring radius
      expect(innerTen(15.31), isFalse); // outside -> a plain ten
      expect(score(15.31), 10); // still a ten, just not an inner ten
    });

    test('distance is radial, not per-axis, and sign-independent', () {
      expect(score(0), 10);
      // (-18, 18) has d = sqrt(648) ~= 25.46 mm: inside the 27.8 ten radius,
      // so a ten regardless of the negative axis and the two non-zero
      // components.
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -18, dyMm: 18)),
        10,
      );
      // (-40, 40) has d = sqrt(3200) ~= 56.57 mm: past the 52.8 ten/nine edge,
      // so an eight, proving the score uses the radial distance not an axis.
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -40, dyMm: 40)),
        8,
      );
    });
  });

  group('25 m pistol — rapid / duel face (.22, rings 5-10)', () {
    const geometry = TargetGeometry.pistol25mRapid();
    int score(double d) =>
        scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
    bool innerTen(double d) =>
        scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

    test('geometry numbers match the ISSF rapid face', () {
      expect(geometry.caliberMm, 5.6);
      expect(geometry.lowestRingValue, 5);
      expect(geometry.highestRing, 10);
      expect(geometry.outerDiameterMm(10), 100);
      expect(geometry.outerDiameterMm(9), 180);
      expect(geometry.outerDiameterMm(5), 500);
      expect(geometry.blackBullDiameterMm, 500);
      expect(geometry.innerTenDiameterMm, 50);
      expect(geometry.innerTenScoringRadiusMm, closeTo(27.8, 1e-9));
    });

    // Thresholds (.22): ring 10 -> 52.8, 9 -> 92.8, 8 -> 132.8, 7 -> 172.8,
    // 6 -> 212.8, 5 -> 252.8 mm. There is no ring below 5.
    test('integer score across rings 5-10, miss below the 5-ring', () {
      const vectors = <(double, int)>[
        (0, 10),
        (52.79, 10),
        (52.81, 9),
        (92.81, 8),
        (132.81, 7),
        (172.81, 6),
        (212.81, 5),
        (252.79, 5),
        (252.81, 0), // outside the 5-ring is a miss (no rings 1-4)
      ];
      for (final (d, ring) in vectors) {
        expect(score(d), ring, reason: 'd=$d mm should score $ring');
      }
    });

    test('inner ten on either side of the 50 mm ring', () {
      expect(innerTen(27.79), isTrue);
      expect(innerTen(27.81), isFalse);
      expect(score(27.81), 10); // still a ten, just not an inner ten
    });
  });

  group('gauge / calibre edge rule', () {
    test('centre-fire 9.65 mm gauge scores wider than a .22', () {
      // The inward-edge gauge rule means a larger calibre reaches one ring
      // further out at the same centre distance.
      const cf = TargetGeometry.pistol25mPrecision(caliber: 9.65);
      expect(cf.caliberMm, 9.65);
      expect(cf.pelletRadiusMm, closeTo(4.825, 1e-9));
      // Ten scoring radius: 25 + 4.825 = 29.825 mm (vs 27.8 for .22).
      expect(scoring.integerScore(cf, const Shot(dxMm: 29.8, dyMm: 0)), 10);
      // A .22 at the same distance is already a nine.
      const rf = TargetGeometry.pistol25mPrecision();
      expect(scoring.integerScore(rf, const Shot(dxMm: 29.8, dyMm: 0)), 9);
      // Centre-fire inner-ten radius: 12.5 + 4.825 = 17.325 mm.
      expect(cf.innerTenScoringRadiusMm, closeTo(17.325, 1e-9));
      expect(scoring.isInnerTen(cf, const Shot(dxMm: 17.3, dyMm: 0)), isTrue);
      expect(scoring.isInnerTen(rf, const Shot(dxMm: 17.3, dyMm: 0)), isFalse);
    });
  });
}
