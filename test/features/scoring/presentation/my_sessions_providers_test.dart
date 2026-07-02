// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the "My sessions" merge (spec 0026): the synced + pending
// union is deduplicated by id (synced wins), tagged synced/pending, and sorted
// most-recent-first by capturedAt (a capturedAt-less record sorts last). Plus
// provider-level guards that the two background reads are non-blocking and
// best-effort: storedPendingProvider surfaces a record the store holds (the
// durable fallback for the local list). The failed-cloud-read path — where the
// read throws and the screen shows a banner (spec 0029) — is covered end-to-end
// in my_sessions_screen_test.dart against the real syncedSessionsProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
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

FeltSessionRecord _felt(String id, {required DateTime capturedAt}) =>
    FeltSessionRecord(
      id: id,
      capturedAt: capturedAt,
      session: const FeltSessionSnapshot(
        group: FeltShooterGroup.one,
        currentHold: 0,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[
            FeltPlacedShot(dx: 1, dy: 1, figureIndex: 0, inner: true),
          ],
        ],
      ),
    );

void main() {
  test('mergeSessionItems interleaves ring and felt newest-first (0082)', () {
    final ring = <MySessionEntry>[
      MySessionEntry(
        record: _record('r1', capturedAt: DateTime.utc(2026, 7, 5)),
        synced: true,
      ),
      MySessionEntry(record: _record('r2'), synced: false), // undated
    ];
    final felt = <FeltSessionRecord>[
      _felt('f1', capturedAt: DateTime.utc(2026, 7, 6)),
    ];

    final items = mergeSessionItems(entries: ring, rounds: felt);

    expect(items.length, 3);
    expect((items[0] as FeltSessionItem).record.id, 'f1'); // newest
    expect((items[1] as RingSessionItem).entry.record.id, 'r1');
    expect((items[2] as RingSessionItem).entry.record.id, 'r2'); // undated last
  });

  test('felt items carry whether the round is synced (spec 0089)', () {
    // The card needs the flag to know whether deleting must also remove the
    // round from the account — the ring card's `entry.synced` counterpart.
    final items = mergeSessionItems(
      entries: const <MySessionEntry>[],
      rounds: <FeltSessionRecord>[
        _felt('local-only', capturedAt: DateTime.utc(2026, 7, 2)),
        _felt('on-account', capturedAt: DateTime.utc(2026, 7)),
      ],
      syncedFeltIds: const <String>{'on-account'},
    );
    expect((items[0] as FeltSessionItem).synced, isFalse);
    expect((items[1] as FeltSessionItem).synced, isTrue);
  });

  test(
    'mergeFeltRounds dedups local and synced by id, newest first (0083)',
    () {
      final merged = mergeFeltRounds(
        local: <FeltSessionRecord>[
          _felt('a', capturedAt: DateTime.utc(2026, 7, 5)),
          _felt('b', capturedAt: DateTime.utc(2026, 7, 4)),
        ],
        synced: <FeltSessionRecord>[
          _felt('a', capturedAt: DateTime.utc(2026, 7, 5)), // duplicate id
          _felt('c', capturedAt: DateTime.utc(2026, 7, 6)), // cloud-only
        ],
      );

      expect(merged.map((r) => r.id), <String>['c', 'a', 'b']);
    },
  );

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
}
