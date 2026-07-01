// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
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

/// One row of the unified "Mine økter" list (spec 0082): a ring session or a
/// finished felt round. Both expose [capturedAt] so the two kinds interleave by
/// date; the list dispatches on the variant to render the right card.
sealed class MySessionItem {
  const MySessionItem();

  /// When the item happened, for sorting (null sorts last).
  DateTime? get capturedAt;
}

/// A ring session in the unified list (spec 0082).
class RingSessionItem extends MySessionItem {
  /// Wraps a ring [entry].
  const RingSessionItem(this.entry);

  /// The ring session entry.
  final MySessionEntry entry;

  @override
  DateTime? get capturedAt => entry.record.capturedAt;
}

/// A finished felt round in the unified list (spec 0082).
class FeltSessionItem extends MySessionItem {
  /// Wraps a finished felt [record].
  const FeltSessionItem(this.record);

  /// The finished felt round.
  final FeltSessionRecord record;

  @override
  DateTime? get capturedAt => record.capturedAt;
}

/// Merges the [local] (spec 0082) and [synced] (spec 0083) felt rounds into one
/// list, deduplicated by id (the synced copy wins the tiebreak) and most-recent
/// first — so a round on both sides shows once and a round from another device
/// appears. A pure function, unit-testable without a widget.
List<FeltSessionRecord> mergeFeltRounds({
  required List<FeltSessionRecord> local,
  required List<FeltSessionRecord> synced,
}) {
  final byId = <String, FeltSessionRecord>{};
  for (final round in local) {
    byId[round.id] = round;
  }
  for (final round in synced) {
    byId[round.id] = round;
  }
  return List<FeltSessionRecord>.unmodifiable(
    byId.values.toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt)),
  );
}

/// Interleaves the ring [entries] and finished felt [rounds] into one list,
/// newest-first by date (undated last) — spec 0082. A pure function, so it is
/// unit-testable without a widget.
List<MySessionItem> mergeSessionItems({
  required List<MySessionEntry> entries,
  required List<FeltSessionRecord> rounds,
}) {
  final items = <MySessionItem>[
    for (final entry in entries) RingSessionItem(entry),
    for (final round in rounds) FeltSessionItem(round),
  ];
  return List<MySessionItem>.unmodifiable(
    items..sort((a, b) {
      final aAt = a.capturedAt;
      final bAt = b.capturedAt;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    }),
  );
}

/// How long to wait for the cloud read before treating it as a failure.
///
/// The synced list is a pure enhancement layered onto the local sessions, so a
/// slow or hanging hosted read (a paused free-tier project, offline, a stalling
/// table) must never be able to spin forever; past this the read times out and
/// throws, surfacing as a non-blocking notice (spec 0029) while the local
/// sessions stand alone until the next refresh.
const Duration _syncedReadTimeout = Duration(seconds: 8);

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

/// The shooter's **synced** sessions from the account
/// ([SessionRepository.list], spec 0026), loaded in the background — a pure
/// enhancement that must never block the local sessions.
///
/// In the real app [sessionRepositoryProvider] is the Supabase-backed
/// repository, whose `list()` hits hosted Supabase. That read can be slow or
/// hang (a paused free-tier project, offline, a stalling table), so it is
/// bounded by a [_syncedReadTimeout]: past it the read **times out and throws**
/// rather than spinning forever.
///
/// A failure — the timeout, a missing table, denied permission, a dropped
/// connection — propagates as this provider's error state (spec 0029). The "My
/// sessions" screen reads the value defensively (`.value ?? const []`) so a
/// failed read can never hide the local sessions, and reads `hasError` to add a
/// non-blocking "couldn't reach the cloud" notice. A **successful** empty read
/// returns `const []` with no error, so an empty account is never mistaken
/// for a failure.
///
/// Refreshed by `ref.invalidate(syncedSessionsProvider)` each time the screen
/// is opened (the picker does this before pushing it), so a session that has
/// synced since the list was last viewed shows on the next open.
final syncedSessionsProvider = FutureProvider<List<SessionRecord>>((ref) {
  return ref
      .watch(sessionRepositoryProvider)
      .list()
      .timeout(_syncedReadTimeout);
});

/// The persisted **pending** sessions ([PendingUploadsStore.load], spec 0025),
/// loaded in the background as the durable fallback for the local list.
///
/// The single shared, durable source the enqueue **always** writes before it
/// flushes (spec 0025). The "My sessions" screen builds its pending rows from
/// the **live** upload queue ([uploadQueueProvider]) synchronously — the
/// just-completed session is there instantly — and folds this stored copy in
/// once it resolves (`.value ?? const []`), so the list is correct even
/// were the recording screen's nested scope ever to update a different queue
/// instance than the screen watches. Best-effort: an unreadable store yields
/// `const []` rather than throwing.
///
/// Refreshed alongside [syncedSessionsProvider] when the screen is opened.
final storedPendingProvider = FutureProvider<List<SessionRecord>>((ref) async {
  try {
    return await ref.watch(pendingUploadsStoreProvider).load();
  } on Object catch (error) {
    if (!kReleaseMode) {
      debugPrint('Failed to load the pending uploads for My sessions: $error');
    }
    return const <SessionRecord>[];
  }
});
