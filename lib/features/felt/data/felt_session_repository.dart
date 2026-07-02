// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';

/// Syncs finished felt rounds to the shooter's account (spec 0083).
///
/// Mirrors the ring `SessionRepository` (spec 0024): the app depends on this
/// interface, not a concrete engine, so the feature is testable without a
/// backend. [upload] is best-effort (never throws); [list] and [deleteById]
/// throw [FeltSyncException] on failure so the caller can tell a real failure
/// apart from an empty account (and never deletes locally what silently
/// stayed on the account).
abstract interface class FeltSessionRepository {
  /// Uploads [record], keyed by its id; idempotent; best-effort.
  Future<void> upload(FeltSessionRecord record);

  /// The account's felt rounds, most recent first.
  Future<List<FeltSessionRecord>> list();

  /// Deletes the account's round with [id] (spec 0089); idempotent. Throws
  /// [FeltSyncException] on failure.
  Future<void> deleteById(String id);
}

/// Thrown when reading the account's felt rounds fails (spec 0083), so a real
/// failure is distinguishable from an empty account.
class FeltSyncException implements Exception {
  /// Wraps the underlying [cause].
  const FeltSyncException(this.cause);

  /// The underlying error.
  final Object cause;

  @override
  String toString() => 'FeltSyncException: $cause';
}

/// A [FeltSessionRepository] that keeps rounds in memory — the default binding
/// and the test fake, so tests run with no backend.
class InMemoryFeltSessionRepository implements FeltSessionRepository {
  /// Creates an empty in-memory repository.
  InMemoryFeltSessionRepository();

  final Map<String, FeltSessionRecord> _byId = <String, FeltSessionRecord>{};

  @override
  Future<void> upload(FeltSessionRecord record) async =>
      _byId[record.id] = record;

  @override
  Future<List<FeltSessionRecord>> list() async {
    final rounds = _byId.values.toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List<FeltSessionRecord>.unmodifiable(rounds);
  }

  @override
  Future<void> deleteById(String id) async => _byId.remove(id);
}
