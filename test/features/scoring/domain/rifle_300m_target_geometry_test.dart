// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Geometry-locking vector tests for the ISSF 300 m rifle face (spec 0018).
//
// These mirror specs 0001 / 0005 / 0017: a table of representative shot offsets
// (mm from centre) -> expected ring, including both sides of each ring boundary
// and the inner-ten edge. They pin the existing geometry so it cannot drift;
// they do not change it. Boundary offsets are nudged by 0.01 mm off the exact
// scoring radius to avoid floating-point ambiguity.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();

  group('300 m rifle face (centre-fire 8 mm gauge, rings 1-10)', () {
    const geometry = TargetGeometry.rifle300m();
    int score(double d) =>
        scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
    bool innerTen(double d) =>
        scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

    test('geometry numbers match the ISSF 300 m rifle face', () {
      expect(geometry.name, '300 m Rifle');
      expect(geometry.caliberMm, 8.0); // centre-fire gauge edge (flagged)
      expect(geometry.pelletRadiusMm, closeTo(4.0, 1e-9));
      expect(geometry.lowestRingValue, 1);
      expect(geometry.highestRing, 10);
      // ringOuterDiametersMm is ordered outermost (ring 1) -> innermost
      // (ring 10): outerDiameterMm(ring) == ringOuterDiametersMm[ring - 1].
      expect(geometry.outerDiameterMm(1), 1000); // outermost
      expect(geometry.outerDiameterMm(10), 100); // innermost
      expect(geometry.outerDiameterMm(9), 200);
      expect(geometry.outerDiameterMm(5), 600);
      expect(geometry.hasUniformRings, isTrue); // uniform 100 mm diameter step
      expect(geometry.blackBullDiameterMm, 600);
      expect(geometry.innerTenDiameterMm, 50);
      expect(geometry.innerTenScoringRadiusMm, closeTo(29.0, 1e-9));
    });

    // Centre-distance scoring thresholds (centre-fire, bullet radius 4.0 mm):
    // ring 10 -> 54.0, 9 -> 104.0, 8 -> 154.0, 7 -> 204.0, 6 -> 254.0,
    // 5 -> 304.0, 4 -> 354.0, 3 -> 404.0, 2 -> 454.0, 1 -> 504.0 mm.
    test('integer score across every ring, both sides of the boundary', () {
      const vectors = <(double, int)>[
        (0, 10),
        (53.99, 10),
        (54.01, 9),
        (103.99, 9),
        (104.01, 8),
        (153.99, 8), // inner side of the 8/9 edge
        (154.01, 7),
        (203.99, 7), // inner side of the 7/8 edge
        (204.01, 6),
        (253.99, 6), // inner side of the 6/7 edge
        (254.01, 5),
        (303.99, 5), // inner side of the 5/6 edge
        (304.01, 4),
        (353.99, 4), // inner side of the 4/5 edge
        (354.01, 3),
        (403.99, 3), // inner side of the 3/4 edge
        (404.01, 2),
        (453.99, 2), // inner side of the 2/3 edge
        (454.01, 1),
        (503.99, 1),
        (504.01, 0), // just past the 1-ring is a miss
        (600, 0),
      ];
      for (final (d, ring) in vectors) {
        expect(score(d), ring, reason: 'd=$d mm should score $ring');
      }
    });

    test('inner ten on either side of the 50 mm ring', () {
      expect(innerTen(28.99), isTrue); // inside the 29.0 mm scoring radius
      expect(innerTen(29.01), isFalse); // outside -> a plain ten
      expect(score(29.01), 10); // still a ten, just not an inner ten
    });

    test('distance is radial, not per-axis, and sign-independent', () {
      // (-30, 30) has d = sqrt(1800) ~= 42.43 mm: inside the 54.0 ten radius,
      // so a ten regardless of the negative axis and the two non-zero
      // components.
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -30, dyMm: 30)),
        10,
      );
      // (-80, 80) has d = sqrt(12800) ~= 113.14 mm: past the 104.0 ten/nine
      // edge, so an eight, proving the score uses the radial distance.
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -80, dyMm: 80)),
        8,
      );
    });
  });

  group('300 m rifle gauge / calibre edge rule', () {
    test('a wider gauge reaches one ring further out at the same distance', () {
      // The inward-edge gauge rule: a larger calibre edge scores wider. A
      // narrower 6 mm gauge (bullet radius 3.0) has a ten radius of 53.0 mm,
      // so a shot at d = 53.5 mm is a nine; the default 8 mm gauge (radius
      // 4.0, ten radius 54.0) scores the same shot a ten.
      const narrow = TargetGeometry.rifle300m(caliber: 6);
      expect(narrow.pelletRadiusMm, closeTo(3.0, 1e-9));
      expect(scoring.integerScore(narrow, const Shot(dxMm: 53.5, dyMm: 0)), 9);
      const wide = TargetGeometry.rifle300m();
      expect(scoring.integerScore(wide, const Shot(dxMm: 53.5, dyMm: 0)), 10);
    });
  });
}
