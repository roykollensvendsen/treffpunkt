// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for the shooter's default place (spec 0102) — the range
/// name that pre-fills the session-setup form.
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `ThemeModeStore` — so the feature is testable without real
/// storage.
abstract interface class DefaultPlaceStore {
  /// Persists [place]; null (or blank) clears any saved value.
  Future<void> save(String? place);

  /// The saved place, or null when none was ever saved (or it was cleared).
  Future<String?> load();
}

/// A [DefaultPlaceStore] that keeps the value in memory only — the default
/// binding and the test fake.
class InMemoryDefaultPlaceStore implements DefaultPlaceStore {
  /// Creates an in-memory store, optionally [seeded].
  InMemoryDefaultPlaceStore({String? seeded}) : _place = seeded;

  String? _place;

  @override
  Future<void> save(String? place) async {
    final trimmed = place?.trim();
    _place = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<String?> load() async => _place;
}

/// A [DefaultPlaceStore] backed by `shared_preferences` (web + mobile).
class SharedPreferencesDefaultPlaceStore implements DefaultPlaceStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesDefaultPlaceStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'default_place';

  @override
  Future<void> save(String? place) async {
    final trimmed = place?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, trimmed);
    }
  }

  @override
  Future<String?> load() async {
    final raw = _prefs.getString(_key)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }
}
