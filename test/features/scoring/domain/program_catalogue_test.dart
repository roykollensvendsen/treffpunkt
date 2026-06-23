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

  test('the 10 m air-rifle reference program is kept but not offered', () {
    // Spec 0001 / decimal-scoring reference and test fixture: the const still
    // exists, but it is deliberately left out of the offered program list at
    // the NSF domain expert's request.
    expect(ProgramCatalogue.airRifle10m.discipline, Discipline.rifle);
    expect(ProgramCatalogue.airRifle10m.totalShots, 10);
    expect(ProgramCatalogue.all, isNot(contains(ProgramCatalogue.airRifle10m)));
    // It is still resolvable by name so a session recorded before the change
    // still loads — it is simply not in the offered list.
    expect(
      ProgramCatalogue.byName('10 m Air Rifle'),
      same(ProgramCatalogue.airRifle10m),
    );
  });

  test('the catalogue seeds the real pistol programs', () {
    expect(ProgramCatalogue.all.length, 9);
    expect(
      ProgramCatalogue.all.every((p) => p.discipline == Discipline.pistol),
      isTrue,
    );

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

  test('hurtigpistol fin/grov: 12 series of 5 on the duel face, timed', () {
    for (final program in <ProgramDefinition>[
      ProgramCatalogue.hurtigpistolFin25m,
      ProgramCatalogue.hurtigpistolGrov25m,
    ]) {
      // 60 shots across three timed stages of 4 x 5 (NSF §8.26).
      expect(program.totalShots, 60);
      expect(program.stages.length, 3);
      expect(program.stages.map((s) => s.seriesCount), <int>[4, 4, 4]);
      expect(
        program.stages.map((s) => s.secondsPerSeries),
        <int>[10, 8, 6],
      );
      // Every series is shot on the duel face (lowest ring 5).
      expect(
        program.stages.every((s) => s.geometry.lowestRingValue == 5),
        isTrue,
      );
    }
    // Fin is rimfire; grov is centre-fire.
    expect(
      ProgramCatalogue.hurtigpistolFin25m.stages[0].geometry.caliberMm,
      5.6,
    );
    expect(
      ProgramCatalogue.hurtigpistolGrov25m.stages[0].geometry.caliberMm,
      9.65,
    );
  });

  test('NAIS fin/grov: 30 shots in six series on the duel face', () {
    for (final program in <ProgramDefinition>[
      ProgramCatalogue.naisFin25m,
      ProgramCatalogue.naisGrov25m,
    ]) {
      // 30 shots: two 150 s, two duel, one 20 s, one 10 s (NSF §8.29).
      expect(program.totalShots, 30);
      expect(program.stages.length, 4);
      expect(program.stages.map((s) => s.seriesCount), <int>[2, 2, 1, 1]);
      expect(
        program.stages.map((s) => s.secondsPerSeries),
        <int?>[150, null, 20, 10],
      );
      // Every series is shot on the duel face (lowest ring 5).
      expect(
        program.stages.every((s) => s.geometry.lowestRingValue == 5),
        isTrue,
      );
    }
    expect(ProgramCatalogue.naisFin25m.stages[0].geometry.caliberMm, 5.6);
    expect(ProgramCatalogue.naisGrov25m.stages[0].geometry.caliberMm, 9.65);
  });

  test('byName resolves a known program and returns null otherwise', () {
    expect(
      ProgramCatalogue.byName('10 m Air Pistol'),
      same(ProgramCatalogue.airPistol10m),
    );
    expect(ProgramCatalogue.byName('Nope'), isNull);
    // Air rifle is not in the offered list but stays resolvable by name, so a
    // session recorded before the change still loads.
    expect(
      ProgramCatalogue.byName('10 m Air Rifle'),
      same(ProgramCatalogue.airRifle10m),
    );

    // Every seeded program is found by its own unique name.
    for (final definition in ProgramCatalogue.all) {
      expect(ProgramCatalogue.byName(definition.name), same(definition));
    }
  });
}
