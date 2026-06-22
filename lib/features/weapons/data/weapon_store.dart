// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/weapons/data/weapons_snapshot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Local storage for the shooter's personal weapons (spec 0019).
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `SessionStore` — so the feature is testable without real storage
/// or I/O. Implementations persist the whole list, replacing it on every
/// change.
abstract interface class WeaponStore {
  /// Persists [weapons], replacing any previously saved list.
  Future<void> save(List<Weapon> weapons);

  /// The saved weapons, or an empty list when none were ever saved.
  Future<List<Weapon>> load();
}

/// A [WeaponStore] that keeps the weapons in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A real restart is simulated in
/// tests by reusing the same instance across a fresh notifier.
class InMemoryWeaponStore implements WeaponStore {
  /// Creates an empty in-memory store.
  InMemoryWeaponStore();

  List<Weapon> _weapons = const <Weapon>[];

  @override
  Future<void> save(List<Weapon> weapons) async =>
      _weapons = List<Weapon>.unmodifiable(weapons);

  @override
  Future<List<Weapon>> load() async => _weapons;
}

/// A [WeaponStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the whole list as one JSON string under [_key] (ADR-0016). Tests
/// drive it with `SharedPreferences.setMockInitialValues`, so no real platform
/// storage is touched.
class SharedPreferencesWeaponStore implements WeaponStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesWeaponStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'personal_weapons';

  @override
  Future<void> save(List<Weapon> weapons) async {
    await _prefs.setString(_key, jsonEncode(WeaponsSnapshot.toJson(weapons)));
  }

  @override
  Future<List<Weapon>> load() async {
    final stored = _prefs.getString(_key);
    if (stored == null) return const <Weapon>[];
    return WeaponsSnapshot.fromJson(jsonDecode(stored) as List<dynamic>);
  }
}
