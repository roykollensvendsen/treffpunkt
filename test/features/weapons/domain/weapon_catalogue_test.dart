// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests asserting the weapon catalogue agrees with the program catalogue:
// every program weapon class is a seeded weapon class and vice versa.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_catalogue.dart';

void main() {
  // A class is identified by its (discipline, label) pair, not its label alone:
  // air rifle and air pistol share the 'Air 4.5 mm' label but are distinct
  // classes. The picker filters the catalogue by *both* discipline and label,
  // so coverage has to be checked on the pair too — a program that lists a
  // label only seeded under another discipline would offer the shooter no
  // weapon.
  String key(Discipline discipline, String label) => '$discipline:$label';

  final classKeys = <String>{
    for (final weaponClass in WeaponCatalogue.all)
      key(weaponClass.discipline, weaponClass.label),
  };

  final classLabels = WeaponCatalogue.all
      .map((weaponClass) => weaponClass.label)
      .toSet();

  // The (discipline, label) pairs every program actually requires: a program's
  // weapon-class labels are only usable in that program's own discipline.
  final programKeys = <String>{
    for (final program in ProgramCatalogue.all)
      for (final label in program.weaponClasses) key(program.discipline, label),
  };

  final programLabels = <String>{
    for (final program in ProgramCatalogue.all) ...program.weaponClasses,
  };

  test('the catalogue is non-empty with distinct classes', () {
    expect(WeaponCatalogue.all, isNotEmpty);
    // A class is identified by (discipline, label): air rifle and air pistol
    // may share the 'Air 4.5 mm' label but are distinct classes.
    final keys = WeaponCatalogue.all
        .map((weaponClass) => key(weaponClass.discipline, weaponClass.label))
        .toList();
    expect(keys.toSet().length, keys.length);
  });

  test('every seeded class label is used by some program', () {
    for (final label in classLabels) {
      expect(
        programLabels,
        contains(label),
        reason: 'class "$label" is not referenced by any program',
      );
    }
  });

  test('every program weapon class is covered by a seeded class of the same '
      'discipline', () {
    for (final programKey in programKeys) {
      expect(
        classKeys,
        contains(programKey),
        reason:
            'program weapon class "$programKey" has no matching seeded class '
            '(the picker filters by discipline *and* label, so a label seeded '
            'only under another discipline offers the shooter no weapon)',
      );
    }
  });
}
