// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/weapons/data/weapon_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// The app's [WeaponStore] for offline persistence (spec 0019).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store.
final weaponStoreProvider = Provider<WeaponStore>(
  (ref) => InMemoryWeaponStore(),
);

/// The weapons loaded from the store at launch, used to seed [WeaponsNotifier].
///
/// `main()` reads the saved list once (`shared_preferences` is already awaited
/// there) and overrides this so the notifier starts populated without an async
/// `build`. Defaults to empty, so a fresh app and every test start with no
/// weapons unless explicitly seeded.
final initialWeaponsProvider = Provider<List<Weapon>>(
  (ref) => const <Weapon>[],
);

/// The shooter's personal weapons, persisted locally so they survive a restart
/// (spec 0019).
///
/// The initial state is seeded from [initialWeaponsProvider] (loaded at
/// launch), and every [add] / [remove] writes the whole list back through
/// [weaponStoreProvider]. Loading is done eagerly in `main()` rather than in
/// `build`, so the notifier stays synchronous and tests never touch real I/O.
class WeaponsNotifier extends Notifier<List<Weapon>> {
  @override
  List<Weapon> build() => ref.read(initialWeaponsProvider);

  /// Appends [weapon] to the shooter's weapons and persists the new list.
  void add(Weapon weapon) {
    state = <Weapon>[...state, weapon];
    _persist();
  }

  /// Removes the weapon with the given [id], if present, and persists.
  void remove(String id) {
    state = state.where((weapon) => weapon.id != id).toList();
    _persist();
  }

  /// Replaces the whole list — a backup restore (spec 0106) — and persists.
  void replaceAll(List<Weapon> weapons) {
    state = List<Weapon>.unmodifiable(weapons);
    _persist();
  }

  void _persist() {
    final write = ref.read(weaponStoreProvider).save(state);
    // Persistence is best-effort and off the happy path (losing one save is not
    // fatal — the in-memory list is the source of truth this run), but a silent
    // failure would be undiagnosable, so surface it in debug builds.
    unawaited(
      write.catchError((Object error, StackTrace stackTrace) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist the personal weapons: $error');
        }
      }),
    );
  }
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
