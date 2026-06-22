// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';

/// A seeded reference weapon class: a discipline and calibre paired with the
/// [label] string that programs use in `ProgramDefinition.weaponClasses`.
///
/// An immutable value type with value equality. The [label] is the single key
/// shared with programs; a personal weapon is matched to the programs it may be
/// used for by this string (see `Weapon`).
@immutable
class WeaponClass {
  /// Creates a weapon class.
  const WeaponClass({
    required this.discipline,
    required this.caliberLabel,
    required this.label,
  });

  /// The discipline this class belongs to (rifle or pistol).
  final Discipline discipline;

  /// Human-readable calibre, e.g. `'.22 LR'` or `'4.5 mm'`.
  final String caliberLabel;

  /// The match label, identical to the strings programs list in their
  /// `weaponClasses` (e.g. `'.22 LR'`, `'Air 4.5 mm'`).
  final String label;

  @override
  bool operator ==(Object other) =>
      other is WeaponClass &&
      other.discipline == discipline &&
      other.caliberLabel == caliberLabel &&
      other.label == label;

  @override
  int get hashCode => Object.hash(discipline, caliberLabel, label);
}
