// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Vector tests for the 10 m air-pistol target (program catalogue).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();
  const geometry = TargetGeometry.airPistol10m();

  // Air pellet 2.25 mm: scoring radius(10)=8.0, (9)=16.0, (1)=80.0.
  // Inner-ten scoring radius = 5/2 + 2.25 = 4.75 mm.
  int score(double d) => scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
  bool innerTen(double d) =>
      scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

  test('10 rings with a 5 mm inner ten', () {
    expect(geometry.highestRing, 10);
    expect(geometry.lowestRingValue, 1);
    expect(geometry.innerTenScoringRadiusMm, closeTo(4.75, 1e-6));
  });

  test('integer scores across the rings', () {
    expect(score(0), 10);
    expect(score(7), 10);
    expect(score(9), 9);
    expect(score(79), 1);
    expect(score(81), 0); // miss
  });

  test('inner ten just inside and outside the 5 mm ring', () {
    expect(innerTen(4), isTrue);
    expect(innerTen(5), isFalse);
  });
}
