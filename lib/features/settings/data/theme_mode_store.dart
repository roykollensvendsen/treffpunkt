// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for the shooter's chosen theme mode (spec 0030).
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `WeaponStore` / `SessionStore` — so the feature is testable
/// without real storage. The chosen [ThemeMode] survives a restart; absent a
/// saved choice the app follows the system/browser theme ([ThemeMode.system]).
abstract interface class ThemeModeStore {
  /// Persists [mode], replacing any previously saved choice.
  Future<void> save(ThemeMode mode);

  /// The saved mode, or [ThemeMode.system] when none was ever saved.
  Future<ThemeMode> load();
}

/// A [ThemeModeStore] that keeps the choice in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A real restart is simulated in
/// tests by reusing the same instance across a fresh notifier.
class InMemoryThemeModeStore implements ThemeModeStore {
  /// Creates an in-memory store defaulting to [ThemeMode.system].
  InMemoryThemeModeStore();

  ThemeMode _mode = ThemeMode.system;

  @override
  Future<void> save(ThemeMode mode) async => _mode = mode;

  @override
  Future<ThemeMode> load() async => _mode;
}

/// A [ThemeModeStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the mode's `ThemeMode.name` (`system` / `light` / `dark`) under
/// [_key] (ADR-0016 / ADR-0018). An absent or unrecognised value loads as
/// [ThemeMode.system], so a fresh install — or a value from a future version —
/// safely follows the system theme. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real platform storage is
/// touched.
class SharedPreferencesThemeModeStore implements ThemeModeStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesThemeModeStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'theme_mode';

  @override
  Future<void> save(ThemeMode mode) async {
    await _prefs.setString(_key, mode.name);
  }

  @override
  Future<ThemeMode> load() async {
    final stored = _prefs.getString(_key);
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) return mode;
    }
    return ThemeMode.system;
  }
}
