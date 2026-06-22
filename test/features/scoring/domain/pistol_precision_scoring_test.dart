// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Vector tests for the 25 m pistol precision target (program catalogue).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const scoring = ScoringService();
  const geometry = TargetGeometry.pistol25mPrecision();

  // .22 pellet radius 2.8 mm, so scoring radius(ring) = outer diameter/2 + 2.8:
  // ring 10 -> 27.8, 9 -> 52.8, 8 -> 77.8, 7 -> 102.8, 5 -> 152.8, 1 -> 252.8.
  // Inner-ten scoring radius = 25/2 + 2.8 = 15.3 mm. (Values below stay clear of
  // the exact boundaries to avoid floating-point ambiguity.)
  int score(double d) => scoring.integerScore(geometry, Shot(dxMm: d, dyMm: 0));
  bool innerTen(double d) =>
      scoring.isInnerTen(geometry, Shot(dxMm: d, dyMm: 0));

  test('geometry has 10 rings, an inner ten and uniform spacing', () {
    expect(geometry.highestRing, 10);
    expect(geometry.hasInnerTen, isTrue);
    expect(geometry.innerTenScoringRadiusMm, closeTo(15.3, 1e-6));
    expect(geometry.hasUniformRings, isTrue);
  });

  test('integer scores across the rings', () {
    expect(score(0), 10);
    expect(score(27), 10);
    expect(score(28), 9);
    expect(score(52), 9);
    expect(score(53), 8);
    expect(score(100), 7);
    expect(score(152), 5);
    expect(score(252), 1);
    expect(score(253), 0); // miss, just past the 1-ring
  });

  test('inner ten just inside and outside the 25 mm ring', () {
    expect(innerTen(15), isTrue);
    expect(innerTen(16), isFalse);
    expect(score(16), 10); // still a ten, just not an inner ten
  });
}
