// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

/// The seeded catalogue of standard NSF/ISSF weapon classes.
///
/// Mirrors `ProgramCatalogue`: an `abstract final class` holding the classes as
/// a const list. Each [WeaponClass.label] is exactly a string the programs use
/// in `ProgramDefinition.weaponClasses`, so a personal weapon can be matched to
/// the programs it is permitted for. The exact NSF class names/calibres are
/// still to confirm with the father (spec 0007) — the labels mirror those the
/// program catalogue already uses.
abstract final class WeaponCatalogue {
  /// Air rifle, 4.5 mm (10 m air rifle).
  static const WeaponClass airRifle = WeaponClass(
    discipline: Discipline.rifle,
    caliberLabel: '4.5 mm',
    label: 'Air 4.5 mm',
  );

  /// Air pistol, 4.5 mm (10 m air pistol).
  static const WeaponClass airPistol = WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '4.5 mm',
    label: 'Air 4.5 mm',
  );

  /// Smallbore (.22 LR) pistol — finpistol, standard, free pistol.
  static const WeaponClass smallborePistol = WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '.22 LR',
    label: '.22 LR',
  );

  /// Centre-fire pistol (7.62–9.65 mm) — grovpistol.
  static const WeaponClass centreFirePistol = WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '7.62–9.65 mm',
    label: 'Centre-fire 7.62–9.65 mm',
  );

  /// All seeded classes, in display order. Two classes may share a
  /// [WeaponClass.label] (e.g. air rifle and air pistol both use
  /// `'Air 4.5 mm'`); [all] holds the distinct classes, while program matching
  /// is by label.
  static const List<WeaponClass> all = <WeaponClass>[
    airRifle,
    airPistol,
    smallborePistol,
    centreFirePistol,
  ];
}
