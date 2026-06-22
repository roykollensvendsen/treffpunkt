// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Vector tests for the 25 m rapid / silhouette target (rings 5-10 only).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();
  const geometry = TargetGeometry.pistol25mRapid();

  // .22 pellet 2.8 mm: scoring radius(10)=52.8, (9)=92.8, (5)=252.8.
  // Inner-ten scoring radius = 50/2 + 2.8 = 27.8 mm.
  int score(double d) => scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
  bool innerTen(double d) =>
      scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

  test('covers rings 5-10 with an inner ten', () {
    expect(geometry.lowestRingValue, 5);
    expect(geometry.highestRing, 10);
    expect(geometry.hasInnerTen, isTrue);
    expect(geometry.innerTenScoringRadiusMm, closeTo(27.8, 1e-6));
  });

  test('integer scores across rings 5-10, miss below the 5-ring', () {
    expect(score(0), 10);
    expect(score(52), 10);
    expect(score(53), 9);
    expect(score(252), 5);
    expect(score(253), 0); // outside the 5-ring is a miss
  });

  test('inner ten just inside and outside the 50 mm ring', () {
    expect(innerTen(27), isTrue);
    expect(innerTen(28), isFalse);
  });
}
