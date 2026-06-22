// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Pure-Dart JSON (de)serialization for the shooter's personal weapons
/// (spec 0019).
///
/// The list is stored as a JSON array of weapon objects, mirroring the single
/// weapon already serialized inside `SessionSnapshot`: every field is carried,
/// the `Discipline` enum is stored by its name, and the optional
/// [Weapon.make] / [Weapon.model] / [Weapon.notes] are `null` when absent. The
/// round-trip is lossless field-by-field, so a saved weapon comes back equal.
///
/// No Flutter or storage imports live here, so the round-trip is a fast,
/// deterministic unit test and the JSON shape is decided once, not smeared
/// across the store or a widget.
abstract final class WeaponsSnapshot {
  /// Encodes [weapons] as a JSON-ready list of weapon maps.
  static List<Map<String, dynamic>> toJson(List<Weapon> weapons) =>
      weapons.map(_weaponJson).toList();

  /// Rebuilds the weapons from a JSON list produced by [toJson].
  static List<Weapon> fromJson(List<dynamic> json) => json
      .map((dynamic entry) => _weaponFrom(entry as Map<String, dynamic>))
      .toList();

  static Map<String, dynamic> _weaponJson(Weapon weapon) => <String, dynamic>{
    'id': weapon.id,
    'name': weapon.name,
    'discipline': weapon.discipline.name,
    'caliberLabel': weapon.caliberLabel,
    'classLabel': weapon.classLabel,
    'make': weapon.make,
    'model': weapon.model,
    'notes': weapon.notes,
  };

  static Weapon _weaponFrom(Map<String, dynamic> map) => Weapon(
    id: map['id'] as String,
    name: map['name'] as String,
    discipline: _disciplineFrom(map['discipline'] as String),
    caliberLabel: map['caliberLabel'] as String,
    classLabel: map['classLabel'] as String,
    make: map['make'] as String?,
    model: map['model'] as String?,
    notes: map['notes'] as String?,
  );

  static Discipline _disciplineFrom(String name) =>
      Discipline.values.firstWhere((value) => value.name == name);
}
