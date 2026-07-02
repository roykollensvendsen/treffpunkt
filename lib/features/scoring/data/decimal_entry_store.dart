// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for the shooter's last decimal-entry choice (spec 0107),
/// mirroring `FeltGroupStore` (spec 0099): the setup toggle starts where it
/// was left. Absent a saved choice the toggle starts off.
abstract interface class DecimalEntryStore {
  /// Persists the choice.
  Future<void> save({required bool enabled});

  /// The saved choice, or null when none was ever saved.
  Future<bool?> load();
}

/// A [DecimalEntryStore] that keeps the choice in memory only — the default
/// binding and the test fake.
class InMemoryDecimalEntryStore implements DecimalEntryStore {
  /// Creates an in-memory store, optionally [seeded].
  InMemoryDecimalEntryStore({bool? seeded}) : _enabled = seeded;

  bool? _enabled;

  @override
  Future<void> save({required bool enabled}) async => _enabled = enabled;

  @override
  Future<bool?> load() async => _enabled;
}

/// A [DecimalEntryStore] backed by `shared_preferences` (web + mobile).
class SharedPreferencesDecimalEntryStore implements DecimalEntryStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesDecimalEntryStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'decimal_entry';

  @override
  Future<void> save({required bool enabled}) async {
    await _prefs.setBool(_key, enabled);
  }

  @override
  Future<bool?> load() async => _prefs.getBool(_key);
}
