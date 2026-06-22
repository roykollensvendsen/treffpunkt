// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the Session aggregate's guided progression (ADR-0012).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

const TargetGeometry _geo = TargetGeometry.pistol25mPrecision();
const Shot _centre = Shot(dxMm: 0, dyMm: 0);

// Two stages: A = 2 series of 2 shots, B = 1 series of 2 shots.
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

Series _fullSeries() =>
    Series(geometry: _geo, capacity: 2).placeShot(_centre).placeShot(_centre);

void main() {
  test('a fresh session starts on the first stage, first series', () {
    final session = Session.start(_program);
    expect(session.currentStageIndex, 0);
    expect(session.currentSeriesNumber, 1);
    expect(session.isComplete, isFalse);
    expect(session.newSeries()?.capacity, 2);
  });

  test('sealing series advances within a stage then to the next stage', () {
    var session = Session.start(_program);

    session = session.sealSeries(_fullSeries()); // stage A, series 1 sealed
    expect(session.currentStageIndex, 0);
    expect(session.currentSeriesNumber, 2);

    session = session.sealSeries(_fullSeries()); // stage A complete
    expect(session.currentStageIndex, 1);
    expect(session.currentSeriesNumber, 1);

    session = session.sealSeries(_fullSeries()); // stage B complete
    expect(session.isComplete, isTrue);
    expect(session.currentStageIndex, _program.stages.length);
    expect(session.newSeries(), isNull);
  });

  test('sealing a completed session throws a StateError', () {
    final session = Session.start(_program)
        .sealSeries(_fullSeries())
        .sealSeries(_fullSeries())
        .sealSeries(_fullSeries());
    expect(session.isComplete, isTrue);
    expect(() => session.sealSeries(_fullSeries()), throwsStateError);
  });
}
