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

  /// Smallbore (.22 LR) rifle — 50 m rifle (miniatyrrifle). Shares the `.22 LR`
  /// label with the smallbore pistol class; the two are distinct on discipline
  /// (the catalogue's uniqueness is on the (discipline, label) pair), just as
  /// air rifle and air pistol share `'Air 4.5 mm'`.
  static const WeaponClass smallboreRifle = WeaponClass(
    discipline: Discipline.rifle,
    caliberLabel: '.22 LR',
    label: '.22 LR',
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

  /// Centre-fire rifle (≤ 8 mm) — 300 m rifle. The exact NSF calibre class is a
  /// confirm-with-the-father flag (spec 0018); the label mirrors the program.
  static const WeaponClass centreFireRifle = WeaponClass(
    discipline: Discipline.rifle,
    caliberLabel: '≤ 8 mm',
    label: 'Centre-fire ≤ 8 mm',
  );

  /// All seeded classes, in display order. Two classes may share a
  /// [WeaponClass.label] (e.g. air rifle and air pistol both use `'Air 4.5
  /// mm'`, and the smallbore rifle and pistol both use `'.22 LR'`); [all] holds
  /// the distinct classes, keyed on the (discipline, label) pair. The picker
  /// matches a program to its classes by discipline *and* label, so a label
  /// shared across disciplines never offers the wrong-discipline class.
  static const List<WeaponClass> all = <WeaponClass>[
    airRifle,
    airPistol,
    smallboreRifle,
    smallborePistol,
    centreFirePistol,
    centreFireRifle,
  ];
}
