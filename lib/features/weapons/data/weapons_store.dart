// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// The shooter's personal weapons, held in memory.
///
/// Persistence is a later increment; for now the list lives for the app
/// session.
class WeaponsNotifier extends Notifier<List<Weapon>> {
  @override
  List<Weapon> build() => const <Weapon>[];

  /// Appends [weapon] to the shooter's weapons.
  void add(Weapon weapon) => state = <Weapon>[...state, weapon];

  /// Removes the weapon with the given [id], if present.
  void remove(String id) =>
      state = state.where((weapon) => weapon.id != id).toList();
}

/// The shooter's personal weapons.
final weaponsProvider = NotifierProvider<WeaponsNotifier, List<Weapon>>(
  WeaponsNotifier.new,
);

/// Holds the weapon chosen for the current session, or `null` if none.
class SelectedWeaponNotifier extends Notifier<Weapon?> {
  @override
  Weapon? build() => null;

  /// Chooses [weapon] for the current session.
  // ignore: use_setters_to_change_properties
  void select(Weapon weapon) => state = weapon;

  /// Clears the current selection.
  void clear() => state = null;
}

/// The weapon chosen for the current session, or `null` if none is chosen.
final selectedWeaponProvider =
    NotifierProvider<SelectedWeaponNotifier, Weapon?>(
      SelectedWeaponNotifier.new,
    );
