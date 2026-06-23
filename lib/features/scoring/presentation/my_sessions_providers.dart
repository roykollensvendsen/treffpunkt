// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

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
/// Loads the synced records ([SessionRepository.list]) and the pending ones,
/// then [mergeMySessions] unions them deduplicated by id (synced winning),
/// tagged, most-recent-first.
///
/// The pending source is the **union** of two views of the same outbox,
/// deduplicated by id:
/// - the **live** upload queue ([uploadQueueProvider]'s in-memory state), so
///   the instant a completed session is enqueued the queue state changes, this
///   provider recomputes, and the screen shows the new row **with no reopen**;
/// - the **persisted** [PendingUploadsStore] (a one-shot
///   [PendingUploadsStore.load]), the single shared, durable source the enqueue
///   **always** writes (spec 0025) before it flushes.
///
/// Reading both makes the list robust no matter how the queue notifier
/// resolves: a completion runs inside `SeriesScreen`'s nested `ProviderScope`,
/// and were its enqueue ever to update a different `uploadQueueProvider`
/// instance than this root provider watches, the live state alone could miss
/// the row — but the store copy still surfaces it, because the enqueue
/// persisted there unconditionally. The live half keeps the immediacy; the
/// store half keeps it correct. The synced read is refreshed by
/// `ref.invalidate(mySessionsProvider)` each time the screen is opened (the
/// picker does this before pushing it).
///
/// Every input is **best-effort**: an unreadable store yields no pending
/// (swallowed, never thrown), the repository returns `const []` on error, so
/// this provider never needs to throw.
final mySessionsProvider = FutureProvider<List<MySessionEntry>>((ref) async {
  final synced = await ref.watch(sessionRepositoryProvider).list();
  final pending = await _pendingUnion(ref);
  return mergeMySessions(synced: synced, pending: pending);
});

/// The pending records to show: the **live** queue state unioned with the
/// **persisted** store, deduplicated by id (the live copy wins a tie, so the
/// freshest in-memory record is kept). Best-effort — an unreadable store
/// contributes nothing rather than throwing.
Future<List<SessionRecord>> _pendingUnion(Ref ref) async {
  final live = ref.watch(uploadQueueProvider);
  final stored = await _loadStored(ref);
  final byId = <String, SessionRecord>{};
  // Stored first, then live overwrites by id — the live (freshest) copy wins.
  for (final record in stored) {
    byId[record.id] = record;
  }
  for (final record in live) {
    byId[record.id] = record;
  }
  return byId.values.toList();
}

/// Loads the persisted pending uploads, swallowing any error so an unreadable
/// store simply contributes no pending records (it never breaks the list).
Future<List<SessionRecord>> _loadStored(Ref ref) async {
  try {
    return await ref.watch(pendingUploadsStoreProvider).load();
  } on Object catch (error) {
    if (!kReleaseMode) {
      debugPrint('Failed to load the pending uploads for My sessions: $error');
    }
    return const <SessionRecord>[];
  }
}
