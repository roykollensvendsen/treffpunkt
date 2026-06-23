// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// Local storage for the queue of completed sessions awaiting upload (spec
/// 0025).
///
/// The durable outbox behind the upload queue: a completed session is enqueued
/// here the instant it finishes (surviving a restart) and removed once it
/// uploads. The rest of the app depends on this interface, not a concrete
/// engine, mirroring `SessionStore` (spec 0009), so the queue is testable with
/// an in-memory fake and never touches real storage.
abstract interface class PendingUploadsStore {
  /// The records waiting to upload, or an empty list when none are stored.
  Future<List<SessionRecord>> load();

  /// Persists [records] as the whole pending list, replacing any previous one.
  Future<void> save(List<SessionRecord> records);
}

/// A [PendingUploadsStore] that keeps the pending list in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A restart is simulated in tests
/// by reusing the same instance across a fresh queue.
class InMemoryPendingUploadsStore implements PendingUploadsStore {
  /// Creates an empty in-memory store.
  InMemoryPendingUploadsStore();

  List<SessionRecord> _records = <SessionRecord>[];

  @override
  Future<List<SessionRecord>> load() async =>
      List<SessionRecord>.unmodifiable(_records);

  @override
  Future<void> save(List<SessionRecord> records) async =>
      _records = List<SessionRecord>.of(records);
}

/// A [PendingUploadsStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the whole pending list as one JSON array under [_key] (ADR-0016).
/// Tests drive it with `SharedPreferences.setMockInitialValues`, so no real
/// platform storage is touched.
class SharedPreferencesPendingUploadsStore implements PendingUploadsStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesPendingUploadsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'pending_session_uploads';

  @override
  Future<List<SessionRecord>> load() async {
    final stored = _prefs.getString(_key);
    if (stored == null) return <SessionRecord>[];
    final list = jsonDecode(stored) as List<dynamic>;
    return <SessionRecord>[
      for (final entry in list)
        SessionRecord.fromJson(entry as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> save(List<SessionRecord> records) async {
    await _prefs.setString(
      _key,
      jsonEncode(<Map<String, dynamic>>[
        for (final record in records) record.toJson(),
      ]),
    );
  }
}
