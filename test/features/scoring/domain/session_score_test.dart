// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for session scoring (per stage + grand total).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

const TargetGeometry _geo = TargetGeometry.pistol25mPrecision();
const Shot _centre = Shot(dxMm: 0, dyMm: 0);
const ProgramDefinition _program = ProgramDefinition(
  name: 'Test',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: _geo,
      shotsPerSeries: 2,
      seriesCount: 2,
    ),
    StageDefinition(
      name: 'B',
      geometry: _geo,
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
  ],
);

Series _twoCentre() =>
    Series(geometry: _geo, capacity: 2).placeShot(_centre).placeShot(_centre);

void main() {
  const scoring = ScoringService();

  test('scoreSession rolls up each stage and the grand total', () {
    final session = Session.start(_program)
        .sealSeries(_twoCentre())
        .sealSeries(_twoCentre())
        .sealSeries(_twoCentre());

    final score = scoring.scoreSession(session);

    expect(score.stages.length, 2);
    // Stage A: 2 series × 2 centre tens = 40; 4 inner tens; max 4 × 10 = 40.
    expect(score.stages[0].total, 40);
    expect(score.stages[0].innerTens, 4);
    expect(score.stages[0].maxTotal, 40);
    // Stage B: 1 series × 2 tens = 20; 2 inner tens; max 20.
    expect(score.stages[1].total, 20);
    expect(score.stages[1].maxTotal, 20);
    // Grand totals.
    expect(score.total, 60);
    expect(score.innerTens, 6);
    expect(score.maxTotal, 60);
  });
}
