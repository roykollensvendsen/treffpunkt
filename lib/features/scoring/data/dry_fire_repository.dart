// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

/// Syncs the dry-fire log to the shooter's account (spec 0162).
///
/// Mirrors the ring `SessionRepository` (spec 0024) and `FeltSessionRepository`
/// (spec 0083): the app depends on this interface, not a concrete engine, so
/// the feature is testable without a backend. [upload] is best-effort (never
/// throws); [list] throws [DryFireSyncException] on failure so the caller can
/// tell a real failure apart from an empty account and keep showing the local
/// log.
abstract interface class DryFireRepository {
  /// Uploads [entries], each keyed by its id; idempotent; best-effort.
  Future<void> upload(List<DryFireEntry> entries);

  /// The account's dry-fire entries, most recent first.
  Future<List<DryFireEntry>> list();
}

/// Thrown when reading the account's dry-fire entries fails (spec 0162), so a
/// real failure is distinguishable from an empty account.
class DryFireSyncException extends SyncException {
  /// Wraps the underlying [cause].
  const DryFireSyncException(super.cause);
}

/// A [DryFireRepository] that keeps entries in memory — the default binding and
/// the test fake, so tests run with no backend.
///
/// [upload] upserts by id (a re-upload of the same id replaces, never
/// duplicates), exactly like the Supabase table's `on conflict (id)`.
class InMemoryDryFireRepository implements DryFireRepository {
  /// Creates an empty in-memory repository.
  InMemoryDryFireRepository();

  final Map<String, DryFireEntry> _byId = <String, DryFireEntry>{};

  @override
  Future<void> upload(List<DryFireEntry> entries) async {
    for (final entry in entries) {
      _byId[entry.id] = entry;
    }
  }

  @override
  Future<List<DryFireEntry>> list() async {
    final entries = _byId.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return List<DryFireEntry>.unmodifiable(entries);
  }
}
