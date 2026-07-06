// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';
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

/// A [FeltSessionStore] backed by `shared_preferences` (ADR-0016).
///
/// Delegates to a [PrefsJsonStore]: one JSON string under one key, and
/// anything unreadable loads as `null`, like never-saved. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real storage is touched.
class SharedPreferencesFeltSessionStore implements FeltSessionStore {
  /// Creates a store reading and writing through [prefs].
  SharedPreferencesFeltSessionStore(SharedPreferences prefs)
    : _store = PrefsJsonStore<FeltSessionSnapshot>(
        prefs,
        key: 'active_felt_session',
        toJson: (snapshot) => snapshot.toJson(),
        fromJson: (json) =>
            FeltSessionSnapshot.fromJson(json! as Map<String, dynamic>),
      );

  final PrefsJsonStore<FeltSessionSnapshot> _store;

  @override
  Future<void> save(FeltSessionSnapshot snapshot) => _store.save(snapshot);

  @override
  Future<FeltSessionSnapshot?> load() => _store.load();

  @override
  Future<void> clear() => _store.clear();
}
