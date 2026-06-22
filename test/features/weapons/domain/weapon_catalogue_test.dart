// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests asserting the weapon catalogue agrees with the program catalogue:
// every program weapon class is a seeded weapon class and vice versa.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_catalogue.dart';

void main() {
  final classLabels = WeaponCatalogue.all
      .map((weaponClass) => weaponClass.label)
      .toList();

  final programLabels = <String>{
    for (final program in ProgramCatalogue.all) ...program.weaponClasses,
  };

  test('the catalogue is non-empty with distinct classes', () {
    expect(WeaponCatalogue.all, isNotEmpty);
    // A class is identified by (discipline, label): air rifle and air pistol
    // may share the 'Air 4.5 mm' label but are distinct classes.
    final keys = WeaponCatalogue.all
        .map((weaponClass) => '${weaponClass.discipline}:${weaponClass.label}')
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

  test('every program weapon class is covered by a seeded class', () {
    for (final label in programLabels) {
      expect(
        classLabels,
        contains(label),
        reason: 'program label "$label" has no weapon class',
      );
    }
  });
}
