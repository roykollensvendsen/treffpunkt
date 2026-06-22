// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';

/// Local storage for the single active session recording (spec 0009).
///
/// The rest of the app depends on this interface, not a concrete engine —
/// mirroring `AuthRepository` and `LocationService` — so the feature is
/// testable without real storage or I/O. Implementations persist one active
/// recording; completing or discarding a session [clear]s it.
abstract interface class SessionStore {
  /// Persists [snapshot] as the active recording, replacing any previous one.
  Future<void> save(SessionSnapshot snapshot);

  /// The saved active recording, or `null` when none is stored.
  Future<SessionSnapshot?> load();

  /// Removes the saved active recording, if any.
  Future<void> clear();
}

/// A [SessionStore] that keeps the active recording in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A real restart is simulated in
/// tests by reusing the same instance across a fresh widget mount.
class InMemorySessionStore implements SessionStore {
  /// Creates an empty in-memory store.
  InMemorySessionStore();

  SessionSnapshot? _snapshot;

  @override
  Future<void> save(SessionSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<SessionSnapshot?> load() async => _snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}

/// A [SessionStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the active recording as one JSON string under [_key] (ADR-0016).
/// Tests drive it with `SharedPreferences.setMockInitialValues`, so no real
/// platform storage is touched.
class SharedPreferencesSessionStore implements SessionStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesSessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'active_session_recording';

  @override
  Future<void> save(SessionSnapshot snapshot) async {
    await _prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  @override
  Future<SessionSnapshot?> load() async {
    final stored = _prefs.getString(_key);
    if (stored == null) return null;
    return SessionSnapshot.fromJson(
      jsonDecode(stored) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> clear() async => _prefs.remove(_key);
}
