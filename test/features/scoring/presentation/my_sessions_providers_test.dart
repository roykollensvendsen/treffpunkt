// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the "My sessions" merge (spec 0026): the synced + pending
// union is deduplicated by id (synced wins), tagged synced/pending, and sorted
// most-recent-first by capturedAt (a capturedAt-less record sorts last). Plus
// provider-level guards that the two background reads are non-blocking and
// best-effort: storedPendingProvider surfaces a record the store holds (the
// durable fallback for the local list), and syncedSessionsProvider never spins
// forever on a hung cloud read (it times out to an empty list).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

import '../../auth/fake_auth_repository.dart';

SessionRecord _record(String id, {DateTime? capturedAt}) => SessionRecord(
  id: id,
  program: '10 m Air Pistol',
  capturedAt: capturedAt,
  total: 90,
  maxTotal: 100,
  innerTens: 0,
  payload: <String, dynamic>{'id': id},
);

void main() {
  test('synced-only records become synced entries', () {
    final entries = mergeMySessions(
      synced: <SessionRecord>[_record('a'), _record('b')],
      pending: const <SessionRecord>[],
    );

    expect(entries.map((e) => e.record.id).toSet(), <String>{'a', 'b'});
    expect(entries.every((e) => e.synced), isTrue);
  });

  test('pending-only records become pending entries', () {
    final entries = mergeMySessions(
      synced: const <SessionRecord>[],
      pending: <SessionRecord>[_record('a')],
    );

    expect(entries.single.record.id, 'a');
    expect(entries.single.synced, isFalse);
  });

  test('with neither source the list is empty', () {
    final entries = mergeMySessions(
      synced: const <SessionRecord>[],
      pending: const <SessionRecord>[],
    );

    expect(entries, isEmpty);
  });

  test('a record in both sources appears once, tagged synced', () {
    final entries = mergeMySessions(
      synced: <SessionRecord>[_record('shared')],
      pending: <SessionRecord>[_record('shared'), _record('only-pending')],
    );

    // The shared id collapses to one entry; the dedup tiebreak makes it synced.
    expect(entries, hasLength(2));
    final shared = entries.firstWhere((e) => e.record.id == 'shared');
    expect(shared.synced, isTrue);
    final pendingOnly = entries.firstWhere(
      (e) => e.record.id == 'only-pending',
    );
    expect(pendingOnly.synced, isFalse);
  });

  test('entries are sorted most-recent-first by capturedAt', () {
    final entries = mergeMySessions(
      synced: <SessionRecord>[
        _record('old', capturedAt: DateTime(2026, 6, 3)),
        _record('new', capturedAt: DateTime(2026, 6, 21)),
        _record('mid', capturedAt: DateTime(2026, 6, 10)),
      ],
      pending: const <SessionRecord>[],
    );

    expect(
      entries.map((e) => e.record.id),
      <String>['new', 'mid', 'old'],
    );
  });

  test('a record without a capturedAt sorts last', () {
    final entries = mergeMySessions(
      synced: <SessionRecord>[
        _record('dated', capturedAt: DateTime(2026, 6, 10)),
        _record('undated'),
      ],
      pending: const <SessionRecord>[],
    );

    expect(entries.map((e) => e.record.id), <String>['dated', 'undated']);
  });

  test(
    'storedPendingProvider surfaces a record only the store holds',
    () async {
      // A record that is in the persisted pending store — the durable fallback
      // the screen folds in alongside the live queue. Were the completion's
      // enqueue ever to update a different queue instance than the screen
      // watches, the live state alone would miss it, but the store copy (the
      // enqueue always persists it) still surfaces it.
      final pendingStore = InMemoryPendingUploadsStore();
      await pendingStore.save(<SessionRecord>[
        _record('store-only', capturedAt: DateTime(2026, 6, 21)),
      ]);
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      final stored = await container.read(storedPendingProvider.future);

      expect(stored.map((r) => r.id), <String>['store-only']);
    },
  );

  testWidgets(
    'syncedSessionsProvider resolves to empty when the cloud read hangs',
    (tester) async {
      // In the real app the repository is the Supabase-backed one, whose list()
      // can hang. The provider must NOT spin forever: it is bounded by a
      // timeout, resolving to const [] so the local sessions are never held up.
      // (Driven under flutter_test's fake clock, so the real 8 s timeout fires
      // without the test taking 8 s of wall time.)
      final repository = _HangingSessionRepository();
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      List<SessionRecord>? resolved;
      unawaited(
        container.read(syncedSessionsProvider.future).then((v) => resolved = v),
      );

      // Well before any sane timeout it is still pending (the read hangs).
      await tester.pump(const Duration(seconds: 1));
      expect(resolved, isNull);

      // Past the bound, it resolves to an empty list rather than spinning.
      await tester.pump(const Duration(seconds: 30));
      expect(resolved, isEmpty);
    },
  );
}

/// A [SessionRepository] whose [list] never completes — a stand-in for a slow
/// or hanging hosted Supabase read.
class _HangingSessionRepository implements SessionRepository {
  final Completer<List<SessionRecord>> _completer =
      Completer<List<SessionRecord>>();

  @override
  Future<void> upload(SessionRecord record) async {}

  @override
  Future<List<SessionRecord>> list() => _completer.future;
}
