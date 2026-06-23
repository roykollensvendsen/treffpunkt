// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// One row of the "My sessions" list (spec 0026): a saved [record] together
/// with whether it has [synced] to the account, or is still waiting in the
/// on-device upload queue (spec 0025).
@immutable
class MySessionEntry {
  /// Creates an entry for [record], tagged [synced] or pending.
  const MySessionEntry({required this.record, required this.synced});

  /// The saved session.
  final SessionRecord record;

  /// Whether this session has synced to the account.
  ///
  /// `true` when it came back from the server ([SessionRepository.list]);
  /// `false` when it is only in the local upload queue (not synced yet).
  final bool synced;

  @override
  bool operator ==(Object other) =>
      other is MySessionEntry &&
      other.record.id == record.id &&
      other.synced == synced;

  @override
  int get hashCode => Object.hash(record.id, synced);
}

/// Merges the [synced] and [pending] records into the "My sessions" list (spec
/// 0026): deduplicated by id (a record in both counts as **synced**), tagged,
/// and sorted most-recent-first by `capturedAt` (records without one go last).
///
/// A pure function of its inputs, so the merge is unit-testable without a
/// widget or a real backend. The same `id` can be in both sources during the
/// window between a session completing (enqueued, spec 0025) and its flush
/// succeeding (uploaded, spec 0024); counting it once as synced is the honest
/// picture and the leftover pending copy is just awaiting removal.
List<MySessionEntry> mergeMySessions({
  required List<SessionRecord> synced,
  required List<SessionRecord> pending,
}) {
  final byId = <String, MySessionEntry>{};
  // Pending first, then synced overwrites by id — so a record present in both
  // ends up tagged synced (the server copy wins the tiebreak).
  for (final record in pending) {
    byId[record.id] = MySessionEntry(record: record, synced: false);
  }
  for (final record in synced) {
    byId[record.id] = MySessionEntry(record: record, synced: true);
  }

  return List<MySessionEntry>.unmodifiable(
    byId.values.toList()..sort((a, b) {
      final aAt = a.record.capturedAt;
      final bAt = b.record.capturedAt;
      // A missing capturedAt sorts last; otherwise newest first.
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    }),
  );
}

/// The shooter's saved sessions for the "My sessions" screen (spec 0026).
///
/// Loads the synced records ([SessionRepository.list]) and the pending ones
/// ([PendingUploadsStore.load], spec 0025), then [mergeMySessions] unions them
/// deduplicated by id (synced winning), tagged, most-recent-first. Both reads
/// are best-effort at their source, so this provider does not need to throw.
final mySessionsProvider = FutureProvider<List<MySessionEntry>>((ref) async {
  final synced = await ref.watch(sessionRepositoryProvider).list();
  final pending = await ref.watch(pendingUploadsStoreProvider).load();
  return mergeMySessions(synced: synced, pending: pending);
});
