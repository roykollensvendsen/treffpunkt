// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

/// Local storage for the shooter's last-used felt group (spec 0099).
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `ThemeModeStore` — so the feature is testable without real
/// storage. The remembered group survives a restart; absent a saved choice
/// the recorder shows the group picker as before.
abstract interface class FeltGroupStore {
  /// Persists [group], replacing any previously saved choice.
  Future<void> save(FeltShooterGroup group);

  /// The saved group, or null when none was ever saved.
  Future<FeltShooterGroup?> load();
}

/// A [FeltGroupStore] that keeps the choice in memory only — the default
/// binding and the test fake.
class InMemoryFeltGroupStore implements FeltGroupStore {
  /// Creates an in-memory store, optionally [seeded].
  InMemoryFeltGroupStore({FeltShooterGroup? seeded}) : _group = seeded;

  FeltShooterGroup? _group;

  @override
  Future<void> save(FeltShooterGroup group) async => _group = group;

  @override
  Future<FeltShooterGroup?> load() async => _group;
}

/// A [FeltGroupStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the group's `name` under [_key]. An absent or unrecognised value
/// loads as null, so a fresh install — or a value from a future version —
/// safely falls back to the picker.
class SharedPreferencesFeltGroupStore implements FeltGroupStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesFeltGroupStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'felt_group';

  @override
  Future<void> save(FeltShooterGroup group) async {
    await _prefs.setString(_key, group.name);
  }

  @override
  Future<FeltShooterGroup?> load() async {
    final raw = _prefs.getString(_key);
    for (final group in FeltShooterGroup.values) {
      if (group.name == raw) return group;
    }
    return null;
  }
}
