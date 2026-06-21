// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the 10 m air-rifle scoring domain.
//
// These vectors are taken verbatim from the Verification section of
// docs/specs/0001-10m-air-rifle-target-and-scoring.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const geometry = TargetGeometry.airRifle10m();
  const scoring = ScoringService();

  // A shot on the x-axis at distance [d] mm from the centre.
  Shot at(double d) => Shot(dxMm: d, dyMm: 0);

  group('TargetGeometry.airRifle10m', () {
    test('caliber and pellet radius', () {
      expect(geometry.caliberMm, 4.5);
      expect(geometry.pelletRadiusMm, 2.25);
    });

    test('ring outer diameters and black bull', () {
      expect(geometry.outerDiameterMm(10), 0.5);
      expect(geometry.outerDiameterMm(1), 45.5);
      expect(geometry.blackBullDiameterMm, 30.5);
    });

    test('scoring-radius thresholds', () {
      expect(geometry.scoringRadiusMm(10), 2.5);
      expect(geometry.scoringRadiusMm(1), 25.0);
      expect(geometry.maxScoringRadiusMm, 25.0);
    });
  });

  group('integer scoring', () {
    const vectors = <(double, int)>[
      (0, 10),
      (2.5, 10),
      (2.6, 9),
      (5, 9),
      (7.5, 8),
      (10, 7),
      (12.5, 6),
      (15, 5),
      (17.5, 4),
      (20, 3),
      (22.5, 2),
      (25, 1),
      (25.01, 0),
      (30, 0),
    ];
    for (final (d, expected) in vectors) {
      test('d=$d scores $expected', () {
        expect(scoring.integerScore(geometry, at(d)), expected);
      });
    }

    test('sign independence', () {
      expect(
        scoring.integerScore(geometry, const Shot(dxMm: -2.5, dyMm: 0)),
        10,
      );
    });

    test('diagonal distance (3,4) -> d=5 -> 9', () {
      expect(scoring.integerScore(geometry, const Shot(dxMm: 3, dyMm: 4)), 9);
    });
  });

  group('decimal scoring', () {
    const vectors = <(double, double)>[
      (0, 10.9),
      (0.25, 10.9),
      (0.5, 10.8),
      (1, 10.6),
      (2.25, 10.1),
      (2.5, 10),
      (2.6, 9.9),
      (5, 9),
      (7.5, 8),
      (10, 7),
      (12.5, 6),
      (15, 5),
      (17.5, 4),
      (20, 3),
      (22.5, 2),
      (25, 1),
      (25.01, 0),
      (30, 0),
    ];
    for (final (d, expected) in vectors) {
      test('d=$d scores $expected', () {
        expect(
          scoring.decimalScore(geometry, at(d)),
          closeTo(expected, 1e-9),
        );
      });
    }

    test('diagonal distance (3,4) -> d=5 -> 9.0', () {
      expect(
        scoring.decimalScore(geometry, const Shot(dxMm: 3, dyMm: 4)),
        closeTo(9, 1e-9),
      );
    });
  });

  group('cross-checks', () {
    const samples = <double>[
      0,
      0.25,
      0.5,
      1,
      2.25,
      2.5,
      2.6,
      5,
      7.5,
      10,
      12.5,
      15,
      17.5,
      20,
      22.5,
      25,
      25.01,
      30,
    ];
    for (final d in samples) {
      test('floor(decimal)==integer and decimal in [0,10.9] at d=$d', () {
        final shot = at(d);
        final decimal = scoring.decimalScore(geometry, shot);
        expect(decimal.floor(), scoring.integerScore(geometry, shot));
        expect(decimal, inInclusiveRange(0.0, 10.9));
      });
    }
  });
}
