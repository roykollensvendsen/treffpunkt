// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

/// A personal weapon the shooter owns: a named instance of a [WeaponClass].
///
/// Immutable value type with value equality. A weapon is built from a class
/// (carrying its [discipline], [caliberLabel] and [classLabel]) plus a
/// shooter-given [name] and a stable [id]; [make], [model] and [notes] are
/// optional. The [classLabel] is what ties the weapon to the programs it may be
/// used for — see [isPermittedFor].
@immutable
class Weapon {
  /// Creates a weapon from its fields. Prefer [Weapon.fromClass].
  const Weapon({
    required this.id,
    required this.name,
    required this.discipline,
    required this.caliberLabel,
    required this.classLabel,
    this.make,
    this.model,
    this.notes,
  });

  /// Builds a weapon from [weaponClass], copying its discipline, calibre and
  /// label, with the shooter-given [name] and stable [id].
  factory Weapon.fromClass(
    WeaponClass weaponClass, {
    required String id,
    required String name,
    String? make,
    String? model,
    String? notes,
  }) {
    return Weapon(
      id: id,
      name: name,
      discipline: weaponClass.discipline,
      caliberLabel: weaponClass.caliberLabel,
      classLabel: weaponClass.label,
      make: make,
      model: model,
      notes: notes,
    );
  }

  /// Stable identifier, unique per weapon (a shooter may own several of a
  /// class).
  final String id;

  /// Shooter-given name shown in the picker, e.g. `'My Walther'`.
  final String name;

  /// The class's discipline.
  final Discipline discipline;

  /// The class's calibre label, e.g. `'.22 LR'`.
  final String caliberLabel;

  /// The class's match label, shared with `ProgramDefinition.weaponClasses`.
  final String classLabel;

  /// Optional manufacturer, e.g. `'Walther'`.
  final String? make;

  /// Optional model, e.g. `'GSP'`.
  final String? model;

  /// Optional free-text notes.
  final String? notes;

  /// Whether this weapon may be used for [program]: true when the program has
  /// no class restriction, or lists this weapon's [classLabel].
  bool isPermittedFor(ProgramDefinition program) =>
      program.weaponClasses.isEmpty ||
      program.weaponClasses.contains(classLabel);

  @override
  bool operator ==(Object other) =>
      other is Weapon &&
      other.id == id &&
      other.name == name &&
      other.discipline == discipline &&
      other.caliberLabel == caliberLabel &&
      other.classLabel == classLabel &&
      other.make == make &&
      other.model == model &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    discipline,
    caliberLabel,
    classLabel,
    make,
    model,
    notes,
  );
}
