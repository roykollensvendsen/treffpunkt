// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for series scoring and inner-ten detection (spec 0004).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

// A small target that records an inner ten: pellet radius 2.5 mm, highest ring
// 3, inner-ten scoring radius 20/2 + 2.5 = 12.5 mm, ring-1 (miss) radius
// 100/2 + 2.5 = 52.5 mm.
const TargetGeometry _innerTenGeometry = TargetGeometry(
  name: 'Inner-ten test',
  caliberMm: 5,
  ringOuterDiametersMm: <double>[100, 60, 40],
  blackBullDiameterMm: 60,
  innerTenDiameterMm: 20,
);

void main() {
  const scoring = ScoringService();

  group('isInnerTen', () {
    test('air rifle records no inner ten', () {
      const geometry = TargetGeometry.airRifle10m();
      expect(
        scoring.isInnerTen(geometry, const Shot(dxMm: 0, dyMm: 0)),
        isFalse,
      );
    });

    test('a target with an inner ten flags central shots at the boundary', () {
      expect(
        scoring.isInnerTen(_innerTenGeometry, const Shot(dxMm: 12.5, dyMm: 0)),
        isTrue,
      );
      expect(
        scoring.isInnerTen(_innerTenGeometry, const Shot(dxMm: 12.6, dyMm: 0)),
        isFalse,
      );
    });
  });

  test('scoreSeries sums rings, counts inner tens and computes the max', () {
    final series = Series(geometry: _innerTenGeometry, capacity: 3)
        .placeShot(const Shot(dxMm: 0, dyMm: 0)) // ring 3, inner ten
        .placeShot(const Shot(dxMm: 12.6, dyMm: 0)) // ring 3, not inner ten
        .placeShot(const Shot(dxMm: 60, dyMm: 0)); // miss (0)

    final score = scoring.scoreSeries(series);

    expect(score.shots.map((s) => s.ring).toList(), <int>[3, 3, 0]);
    expect(score.innerTens, 1);
    expect(score.total, 6);
    expect(score.maxTotal, 9);
  });

  test('an empty series scores zero with the full ceiling as the maximum', () {
    final score = scoring.scoreSeries(
      Series(geometry: _innerTenGeometry, capacity: 3),
    );
    expect(score.shots, isEmpty);
    expect(score.total, 0);
    expect(score.innerTens, 0);
    expect(score.maxTotal, 9); // capacity 3 × highest ring 3, regardless
  });

  test('air rifle has uniform rings; the inner-ten test target does not', () {
    expect(const TargetGeometry.airRifle10m().hasUniformRings, isTrue);
    expect(_innerTenGeometry.hasUniformRings, isFalse);
  });
}
