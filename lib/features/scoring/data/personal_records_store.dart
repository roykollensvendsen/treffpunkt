// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';

/// Local storage for the shooter's manual personal-record baselines (spec
/// 0102): one [ExerciseResult] per exercise key — a catalogue program name,
/// or the felt course per group.
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `ThemeModeStore` — so the feature is testable without real
/// storage.
abstract interface class PersonalRecordsStore {
  /// Persists [records], replacing the previously saved map.
  Future<void> save(Map<String, ExerciseResult> records);

  /// The saved baselines; empty when none were ever saved.
  Future<Map<String, ExerciseResult>> load();
}

/// A [PersonalRecordsStore] that keeps the map in memory only — the default
/// binding and the test fake.
class InMemoryPersonalRecordsStore implements PersonalRecordsStore {
  /// Creates an in-memory store, optionally [seeded].
  InMemoryPersonalRecordsStore({Map<String, ExerciseResult>? seeded})
    : _records = Map<String, ExerciseResult>.of(seeded ?? const {});

  Map<String, ExerciseResult> _records;

  @override
  Future<void> save(Map<String, ExerciseResult> records) async {
    _records = Map<String, ExerciseResult>.of(records);
  }

  @override
  Future<Map<String, ExerciseResult>> load() async =>
      Map<String, ExerciseResult>.of(_records);
}

/// A [PersonalRecordsStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the map as JSON under [_key]:
/// `{"<exercise>": {"points": 372, "inner": 11}}`. Anything unreadable — a
/// missing key, malformed JSON, a wrong shape — loads as empty, so a broken
/// value can never take the app down.
class SharedPreferencesPersonalRecordsStore implements PersonalRecordsStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesPersonalRecordsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'personal_records';

  @override
  Future<void> save(Map<String, ExerciseResult> records) async {
    await _prefs.setString(
      _key,
      jsonEncode(<String, dynamic>{
        for (final entry in records.entries)
          entry.key: <String, int>{
            'points': entry.value.points,
            'inner': entry.value.inner,
          },
      }),
    );
  }

  @override
  Future<Map<String, ExerciseResult>> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return <String, ExerciseResult>{
        for (final entry in decoded.entries)
          entry.key: (
            points: (entry.value as Map<String, dynamic>)['points'] as int,
            inner: (entry.value as Map<String, dynamic>)['inner'] as int,
          ),
      };
    } on Object {
      return const {};
    }
  }
}
