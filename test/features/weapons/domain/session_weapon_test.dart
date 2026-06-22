// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the optional weapon carried by the Session aggregate.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

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
      seriesCount: 1,
    ),
  ],
);

final Weapon _weapon = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '.22 LR',
    label: '.22 LR',
  ),
  id: 'w1',
  name: 'My pistol',
);

Series _fullSeries() =>
    Series(geometry: _geo, capacity: 2).placeShot(_centre).placeShot(_centre);

void main() {
  test('Session.start carries the given weapon', () {
    final session = Session.start(_program, weapon: _weapon);
    expect(session.weapon, _weapon);
  });

  test('weapon defaults to null when not given', () {
    expect(Session.start(_program).weapon, isNull);
  });

  test('sealSeries preserves the weapon', () {
    final session = Session.start(
      _program,
      weapon: _weapon,
    ).sealSeries(_fullSeries());
    expect(session.weapon, _weapon);
  });
}
