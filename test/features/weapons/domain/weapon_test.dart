// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the personal Weapon value type: building from a class, value
// equality, and the "permitted for a program" rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

const WeaponClass _smallbore = WeaponClass(
  discipline: Discipline.pistol,
  caliberLabel: '.22 LR',
  label: '.22 LR',
);

const ProgramDefinition _restricted = ProgramDefinition(
  name: 'R',
  discipline: Discipline.pistol,
  weaponClasses: <String>['.22 LR'],
  stages: <StageDefinition>[],
);

const ProgramDefinition _otherClass = ProgramDefinition(
  name: 'O',
  discipline: Discipline.pistol,
  weaponClasses: <String>['Centre-fire 7.62–9.65 mm'],
  stages: <StageDefinition>[],
);

const ProgramDefinition _unrestricted = ProgramDefinition(
  name: 'U',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[],
);

void main() {
  test('fromClass copies the class and keeps the name and id', () {
    final weapon = Weapon.fromClass(
      _smallbore,
      id: 'w1',
      name: 'My pistol',
    );
    expect(weapon.id, 'w1');
    expect(weapon.name, 'My pistol');
    expect(weapon.classLabel, _smallbore.label);
    expect(weapon.discipline, _smallbore.discipline);
    expect(weapon.caliberLabel, _smallbore.caliberLabel);
  });

  test('fromClass carries make, model and notes through', () {
    final weapon = Weapon.fromClass(
      _smallbore,
      id: 'w1',
      name: 'My pistol',
      make: 'Walther',
      model: 'GSP',
      notes: 'club gun',
    );
    expect(weapon.make, 'Walther');
    expect(weapon.model, 'GSP');
    expect(weapon.notes, 'club gun');
  });

  test('weapons with the same fields are equal', () {
    final a = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    final b = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('weapons differing in a field are unequal', () {
    final a = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    final differentName = Weapon.fromClass(_smallbore, id: 'w1', name: 'B');
    final differentId = Weapon.fromClass(_smallbore, id: 'w2', name: 'A');
    expect(a, isNot(differentName));
    expect(a, isNot(differentId));
  });

  test('weapons differing only in make are unequal', () {
    final a = Weapon.fromClass(_smallbore, id: 'w1', name: 'A', make: 'X');
    final differentMake = Weapon.fromClass(
      _smallbore,
      id: 'w1',
      name: 'A',
      make: 'Y',
    );
    expect(a, isNot(differentMake));
  });

  test('weapons differing only in notes are unequal', () {
    final a = Weapon.fromClass(_smallbore, id: 'w1', name: 'A', notes: 'one');
    final differentNotes = Weapon.fromClass(
      _smallbore,
      id: 'w1',
      name: 'A',
      notes: 'two',
    );
    expect(a, isNot(differentNotes));
  });

  test('isPermittedFor matches a program listing the class', () {
    final weapon = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    expect(weapon.isPermittedFor(_restricted), isTrue);
  });

  test('isPermittedFor allows an unrestricted program', () {
    final weapon = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    expect(weapon.isPermittedFor(_unrestricted), isTrue);
  });

  test('isPermittedFor rejects a program listing only other classes', () {
    final weapon = Weapon.fromClass(_smallbore, id: 'w1', name: 'A');
    expect(weapon.isPermittedFor(_otherClass), isFalse);
  });
}
