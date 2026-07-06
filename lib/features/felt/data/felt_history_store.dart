// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';

/// Local storage for finished felt rounds (spec 0082).
///
/// Mirrors the ring `PendingUploadsStore` (spec 0025) but without an upload
/// queue — felt cloud sync is a later step. The app depends on this interface,
/// so the feature is testable without real I/O.
abstract interface class FeltHistoryStore {
  /// The saved finished rounds (newest-first is the caller's responsibility).
  Future<List<FeltSessionRecord>> load();

  /// Replaces the stored rounds with [records].
  Future<void> save(List<FeltSessionRecord> records);
}

/// A [FeltHistoryStore] that keeps rounds in memory only — the default binding
/// and the test fake, so tests run with no real I/O.
class InMemoryFeltHistoryStore implements FeltHistoryStore {
  /// Creates an empty in-memory store.
  InMemoryFeltHistoryStore();

  List<FeltSessionRecord> _records = const <FeltSessionRecord>[];

  @override
  Future<List<FeltSessionRecord>> load() async => _records;

  @override
  Future<void> save(List<FeltSessionRecord> records) async =>
      _records = List<FeltSessionRecord>.unmodifiable(records);
}

/// A [FeltHistoryStore] backed by `shared_preferences` (ADR-0016).
///
/// Delegates to a [PrefsJsonListStore]: a JSON array under one key, and a
/// malformed store reads as empty rather than throwing, so a bad write can
/// never brick the history. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real storage is touched.
class SharedPreferencesFeltHistoryStore implements FeltHistoryStore {
  /// Creates a store reading and writing through [prefs].
  SharedPreferencesFeltHistoryStore(SharedPreferences prefs)
    : _store = PrefsJsonListStore<FeltSessionRecord>(
        prefs,
        key: 'felt_session_history',
        toJson: (record) => record.toJson(),
        fromJson: (json) =>
            FeltSessionRecord.fromJson(json! as Map<String, dynamic>),
      );

  final PrefsJsonListStore<FeltSessionRecord> _store;

  @override
  Future<List<FeltSessionRecord>> load() => _store.load();

  @override
  Future<void> save(List<FeltSessionRecord> records) => _store.save(records);
}
