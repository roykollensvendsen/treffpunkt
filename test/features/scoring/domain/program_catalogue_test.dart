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
}
