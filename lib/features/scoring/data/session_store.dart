// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';
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
/// Delegates to a [PrefsJsonStore]: the active recording lives as one JSON
/// string under one key (ADR-0016), and anything unreadable loads as `null`,
/// like never-saved. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real platform storage is
/// touched.
class SharedPreferencesSessionStore implements SessionStore {
  /// Creates a store reading and writing through [prefs].
  SharedPreferencesSessionStore(SharedPreferences prefs)
    : _store = PrefsJsonStore<SessionSnapshot>(
        prefs,
        key: 'active_session_recording',
        toJson: (snapshot) => snapshot.toJson(),
        fromJson: (json) =>
            SessionSnapshot.fromJson(json! as Map<String, dynamic>),
      );

  final PrefsJsonStore<SessionSnapshot> _store;

  @override
  Future<void> save(SessionSnapshot snapshot) => _store.save(snapshot);

  @override
  Future<SessionSnapshot?> load() => _store.load();

  @override
  Future<void> clear() => _store.clear();
}
