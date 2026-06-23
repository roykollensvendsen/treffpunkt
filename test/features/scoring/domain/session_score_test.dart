// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for session scoring (per stage + grand total).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
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

// A shot 40 mm off centre — ring 9 on the 25 m precision face (ring 10 ends at
// ~27.8 mm, ring 9 at ~52.8 mm), not an inner ten, so an off-centre series
// differs from an all-centre one in both total and inner-ten count.
const Shot _nine = Shot(dxMm: 40, dyMm: 0);

Series _twoCentre() =>
    Series(geometry: _geo, capacity: 2).placeShot(_centre).placeShot(_centre);

// A two-shot series: one centre ten (inner) and one ring-9 off-centre shot.
Series _tenAndNine() =>
    Series(geometry: _geo, capacity: 2).placeShot(_centre).placeShot(_nine);

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

  test('each stage keeps the per-series (skive) scores in firing order', () {
    // Stage A holds two distinct series, Stage B one — so a stage's series list
    // is the per-skive breakdown, not just the subtotal.
    final session = Session.start(_program)
        .sealSeries(_twoCentre()) // A series 1: 20, 2 inner tens
        .sealSeries(_tenAndNine()) // A series 2: 19, 1 inner ten
        .sealSeries(_tenAndNine()); // B series 1: 19, 1 inner ten

    final score = scoring.scoreSession(session);

    // Stage A has two series, in firing order.
    final stageA = score.stages[0];
    expect(stageA.series, hasLength(2));
    expect(stageA.series[0].total, 20);
    expect(stageA.series[0].innerTens, 2);
    expect(stageA.series[0].maxTotal, 20);
    expect(stageA.series[1].total, 19);
    expect(stageA.series[1].innerTens, 1);
    expect(stageA.series[1].maxTotal, 20);

    // Stage B has one series (a single-skive stage still lists its skive).
    final stageB = score.stages[1];
    expect(stageB.series, hasLength(1));
    expect(stageB.series[0].total, 19);
    expect(stageB.series[0].innerTens, 1);
    expect(stageB.series[0].maxTotal, 20);

    // The stage rollups are exactly the sums of their series.
    for (final stage in score.stages) {
      expect(
        stage.total,
        stage.series.fold<int>(0, (sum, s) => sum + s.total),
      );
      expect(
        stage.innerTens,
        stage.series.fold<int>(0, (sum, s) => sum + s.innerTens),
      );
      expect(
        stage.maxTotal,
        stage.series.fold<int>(0, (sum, s) => sum + s.maxTotal),
      );
    }
  });

  test('the per-series list length matches each stage seriesCount', () {
    // Drives finpistol25m to completion (6 + 6 series) and checks the breakdown
    // length matches the program, regardless of where shots land.
    var session = Session.start(ProgramCatalogue.finpistol25m);
    while (!session.isComplete) {
      final fresh = session.newSeries()!;
      var series = fresh;
      for (var i = 0; i < fresh.capacity; i++) {
        series = series.placeShot(_centre);
      }
      session = session.sealSeries(series);
    }

    final score = scoring.scoreSession(session);
    const program = ProgramCatalogue.finpistol25m;
    expect(score.stages, hasLength(program.stages.length));
    for (var i = 0; i < program.stages.length; i++) {
      expect(score.stages[i].series, hasLength(program.stages[i].seriesCount));
    }
  });
}
