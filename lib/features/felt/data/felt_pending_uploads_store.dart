// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';

/// Local storage for the queue of finished felt rounds awaiting upload (spec
/// 0144).
///
/// The durable outbox behind the felt upload queue — the felt mirror of the
/// ring's `PendingUploadsStore` (spec 0025): a finished round is enqueued here
/// the instant it is saved (surviving a restart or an offline session) and
/// removed once its upload *and* any competition-result submission succeeded.
/// The rest of the app depends on this interface, not a concrete engine, so
/// the queue is testable with an in-memory fake and never touches real
/// storage.
abstract interface class FeltPendingUploadsStore {
  /// The rounds waiting to upload, or an empty list when none are stored.
  Future<List<FeltSessionRecord>> load();

  /// Persists [records] as the whole pending list, replacing any previous one.
  Future<void> save(List<FeltSessionRecord> records);
}

/// A [FeltPendingUploadsStore] that keeps the pending list in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A restart is simulated in tests
/// by reusing the same instance across a fresh container.
class InMemoryFeltPendingUploadsStore implements FeltPendingUploadsStore {
  /// Creates an empty in-memory store.
  InMemoryFeltPendingUploadsStore();

  List<FeltSessionRecord> _records = <FeltSessionRecord>[];

  @override
  Future<List<FeltSessionRecord>> load() async =>
      List<FeltSessionRecord>.unmodifiable(_records);

  @override
  Future<void> save(List<FeltSessionRecord> records) async =>
      _records = List<FeltSessionRecord>.of(records);
}

/// A [FeltPendingUploadsStore] backed by `shared_preferences` (web + mobile).
///
/// Delegates to a [PrefsJsonListStore]: the whole pending list lives as one
/// JSON array under one key (ADR-0016), and anything unreadable loads as the
/// empty list, like never-saved — a pre-0144 install has no key yet, so it
/// seeds an empty queue (spec 0144's one-time migration). Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real storage is touched.
class SharedPreferencesFeltPendingUploadsStore
    implements FeltPendingUploadsStore {
  /// Creates a store reading and writing through [prefs].
  SharedPreferencesFeltPendingUploadsStore(SharedPreferences prefs)
    : _store = PrefsJsonListStore<FeltSessionRecord>(
        prefs,
        key: 'felt_pending_uploads',
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
