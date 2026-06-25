// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the 10 m air sprint / duel face used by Storluft (spec 0043):
// rings 5–10 on a larger face, inner ten 11.5 mm, integer + X scoring.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const geometry = TargetGeometry.airDuel10m();
  const scoring = ScoringService();

  test('the face has rings 5–10 on a 155.5 mm outer ring', () {
    expect(geometry.lowestRingValue, 5);
    expect(geometry.highestRing, 10);
    expect(geometry.ringOuterDiametersMm, hasLength(6));
    expect(geometry.outerDiameterMm(5), 155.5);
    expect(geometry.outerDiameterMm(10), 23);
  });

  test('a centre shot is a ten and an inner ten', () {
    const centre = Shot(dxMm: 0, dyMm: 0);
    expect(scoring.integerScore(geometry, centre), 10);
    expect(scoring.isInnerTen(geometry, centre), isTrue);
  });

  test('the gauge edge rule applies on the 10-ring', () {
    // 10-ring scoring radius = 23/2 + pellet 2.25 = 13.75 mm.
    expect(scoring.integerScore(geometry, const Shot(dxMm: 13, dyMm: 0)), 10);
    expect(scoring.integerScore(geometry, const Shot(dxMm: 14, dyMm: 0)), 9);
  });

  test('beyond the 5-ring is a miss', () {
    // 5-ring scoring radius = 155.5/2 + 2.25 = 80 mm.
    expect(scoring.integerScore(geometry, const Shot(dxMm: 79, dyMm: 0)), 5);
    expect(scoring.integerScore(geometry, const Shot(dxMm: 81, dyMm: 0)), 0);
  });
}
