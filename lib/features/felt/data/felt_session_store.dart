// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

/// Local storage for the single active felt round (spec 0081).
///
/// Mirrors the ring `SessionStore` (spec 0009): the app depends on this
/// interface, not a concrete engine, so the feature is testable without real
/// I/O. Implementations persist one active round; finishing or discarding it
/// [clear]s it.
abstract interface class FeltSessionStore {
  /// Persists [snapshot] as the active round, replacing any previous one.
  Future<void> save(FeltSessionSnapshot snapshot);

  /// The saved active round, or `null` when none is stored.
  Future<FeltSessionSnapshot?> load();

  /// Removes the saved active round, if any.
  Future<void> clear();
}

/// A [FeltSessionStore] that keeps the active round in memory only — the
/// default binding and the test fake, so tests run with no real I/O.
class InMemoryFeltSessionStore implements FeltSessionStore {
  /// Creates an empty in-memory store.
  InMemoryFeltSessionStore();

  FeltSessionSnapshot? _snapshot;

  @override
  Future<void> save(FeltSessionSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<FeltSessionSnapshot?> load() async => _snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}

/// A [FeltSessionStore] backed by `shared_preferences` (ADR-0016): one JSON
/// string under [_key]. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real storage is touched.
class SharedPreferencesFeltSessionStore implements FeltSessionStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesFeltSessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'active_felt_session';

  @override
  Future<void> save(FeltSessionSnapshot snapshot) async {
    await _prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  @override
  Future<FeltSessionSnapshot?> load() async {
    final stored = _prefs.getString(_key);
    if (stored == null) return null;
    return FeltSessionSnapshot.fromJson(
      jsonDecode(stored) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> clear() async => _prefs.remove(_key);
}
