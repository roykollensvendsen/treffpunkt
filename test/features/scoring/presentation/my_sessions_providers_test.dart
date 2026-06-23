// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the "My sessions" merge (spec 0026): the synced + pending
// union is deduplicated by id (synced wins), tagged synced/pending, and sorted
// most-recent-first by capturedAt (a capturedAt-less record sorts last). Plus a
// provider-level guard that the pending half is the UNION of the live upload
// queue and the persisted store, so a record only the store knows about still
// shows (robustness against a queue/scope-instance discrepancy).
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
    'mySessionsProvider unions the persisted store, not only the live queue',
    () async {
      // A record that is in the persisted pending store but NOT in the live
      // upload queue's in-memory state — the exact case the store-union guards:
      // were the completion's enqueue ever to update a different queue instance
      // than this provider watches, the live state alone would miss it, but the
      // store copy (the enqueue always persists it) still surfaces it.
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

      final entries = await container.read(mySessionsProvider.future);

      // The store-only record shows, tagged pending — even though the live
      // queue (read fresh here) never had it in its in-memory state.
      expect(entries, hasLength(1));
      expect(entries.single.record.id, 'store-only');
      expect(entries.single.synced, isFalse);
    },
  );
}
