// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the program-definition model and seeded catalogue.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  test('a stage and a program report their total shots', () {
    const stage = StageDefinition(
      name: 'Presisjon',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 5,
      seriesCount: 6,
    );
    expect(stage.totalShots, 30);

    const program = ProgramDefinition(
      name: 'Test',
      discipline: Discipline.pistol,
      stages: <StageDefinition>[stage, stage],
    );
    expect(program.totalShots, 60);
  });

  test('the catalogue contains the 10 m air-rifle program', () {
    expect(ProgramCatalogue.all, contains(ProgramCatalogue.airRifle10m));
    expect(ProgramCatalogue.airRifle10m.discipline, Discipline.rifle);
    expect(ProgramCatalogue.airRifle10m.totalShots, 10);
  });

  test('the catalogue seeds the real pistol programs', () {
    expect(ProgramCatalogue.all.length, 6);

    // Standard pistol: three timed stages of 4 x 5 = 60.
    expect(ProgramCatalogue.standardPistol25m.stages.length, 3);
    expect(ProgramCatalogue.standardPistol25m.totalShots, 60);

    // Finpistol: precision then duel on two different faces, 60 shots.
    const fin = ProgramCatalogue.finpistol25m;
    expect(fin.stages.length, 2);
    expect(fin.totalShots, 60);
    expect(fin.stages[0].geometry.lowestRingValue, 1); // precision face
    expect(fin.stages[1].geometry.lowestRingValue, 5); // rapid / duel face

    // Grovpistol uses a centre-fire calibre.
    expect(ProgramCatalogue.grovpistol25m.stages[0].geometry.caliberMm, 9.65);
  });
}
