// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the "My sessions" screen (spec 0026): a row per saved
// session with program / score / weapon and a "not synced" badge only on
// pending ones; the empty state; tapping a row opens the read-only scorecard
// (per-stage + per-series breakdown); a payload naming an unresolvable program
// shows a graceful message instead of crashing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

import '../../auth/fake_auth_repository.dart';

const Shot _centre = Shot(dxMm: 0, dyMm: 0);
const ScoringService _scoring = ScoringService();

/// A completed-session record for [program] (every series shot centre), tagged
/// with the given [id] and optional [weaponName].
SessionRecord _recordFor(
  ProgramDefinition program, {
  required String id,
  String? weaponName,
  DateTime? capturedAt,
}) {
  var session = Session.start(
    program,
    metadata: capturedAt == null
        ? null
        : SessionMetadata(capturedAt: capturedAt),
  );
  for (final stage in program.stages) {
    for (var s = 0; s < stage.seriesCount; s++) {
      var series = session.newSeries()!;
      for (var shot = 0; shot < stage.shotsPerSeries; shot++) {
        series = series.placeShot(_centre);
      }
      session = session.sealSeries(series);
    }
  }
  final record = SessionRecord.fromSession(
    session,
    _scoring.scoreSession(session),
    id: id,
  );
  if (weaponName == null) return record;
  // Re-stamp the queryable weapon name (the recording carried no Weapon here).
  return SessionRecord(
    id: record.id,
    program: record.program,
    capturedAt: record.capturedAt,
    placeLabel: record.placeLabel,
    latitude: record.latitude,
    longitude: record.longitude,
    weaponName: weaponName,
    total: record.total,
    maxTotal: record.maxTotal,
    innerTens: record.innerTens,
    payload: record.payload,
  );
}

/// A record whose payload names a program NOT resolvable by [ProgramCatalogue],
/// so opening its detail forces the FormatException / graceful-message path.
SessionRecord _unresolvableRecord({required String id}) {
  final good = _recordFor(ProgramCatalogue.airPistol10m, id: id);
  final brokenPayload = Map<String, dynamic>.of(good.payload);
  brokenPayload['program'] = 'No Such Program 9000';
  return SessionRecord(
    id: good.id,
    program: 'No Such Program 9000',
    total: good.total,
    maxTotal: good.maxTotal,
    innerTens: good.innerTens,
    payload: brokenPayload,
  );
}

Widget _app({
  required List<SessionRecord> synced,
  required List<SessionRecord> pending,
}) {
  final repository = InMemorySessionRepository();
  final pendingStore = InMemoryPendingUploadsStore();
  return ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repository),
      pendingUploadsStoreProvider.overrideWithValue(pendingStore),
    ],
    child: _Seeder(
      repository: repository,
      pendingStore: pendingStore,
      synced: synced,
      pending: pending,
    ),
  );
}

/// Builds the screen with a custom [repository] (e.g. one whose `list()`
/// throws), seeding only the local [pending] sessions — used to exercise the
/// cloud-read-failure path (spec 0029).
Widget _appWith({
  required SessionRepository repository,
  required List<SessionRecord> pending,
}) {
  final pendingStore = InMemoryPendingUploadsStore();
  return ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repository),
      pendingUploadsStoreProvider.overrideWithValue(pendingStore),
    ],
    child: _Seeder(
      repository: repository,
      pendingStore: pendingStore,
      synced: const <SessionRecord>[],
      pending: pending,
    ),
  );
}

/// A [SessionRepository] whose synced read always fails (spec 0029), so the
/// screen takes the cloud-read-failure path. The upload is a no-op.
class _ThrowingSessionRepository implements SessionRepository {
  @override
  Future<void> upload(SessionRecord record) async {}

  @override
  Future<List<SessionRecord>> list() async =>
      throw const SessionSyncException('boom');
  @override
  Future<void> deleteById(String id) async {}
}

/// Seeds the fakes before mounting the screen, so the FutureProvider reads the
/// records on its first load.
class _Seeder extends StatefulWidget {
  const _Seeder({
    required this.repository,
    required this.pendingStore,
    required this.synced,
    required this.pending,
  });

  final SessionRepository repository;
  final InMemoryPendingUploadsStore pendingStore;
  final List<SessionRecord> synced;
  final List<SessionRecord> pending;

  @override
  State<_Seeder> createState() => _SeederState();
}

class _SeederState extends State<_Seeder> {
  late final Future<void> _seeded = _seed();

  Future<void> _seed() async {
    for (final record in widget.synced) {
      await widget.repository.upload(record);
    }
    await widget.pendingStore.save(widget.pending);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<void>(
        future: _seeded,
        builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done
            ? const MySessionsScreen()
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  testWidgets(
    'shows a sync-error banner when the cloud read fails, and still lists the '
    'local sessions',
    (tester) async {
      await tester.pumpWidget(
        _appWith(
          repository: _ThrowingSessionRepository(),
          pending: <SessionRecord>[
            _recordFor(
              ProgramCatalogue.airPistol10m,
              id: 'pending-1',
              capturedAt: DateTime(2026, 6, 21, 10),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The failure is surfaced, but the local session still renders below it.
      expect(find.byKey(syncErrorBannerKey), findsOneWidget);
      expect(find.byKey(mySessionCard('pending-1')), findsOneWidget);
      expect(find.byKey(noSessionsKey), findsNothing);
    },
  );

  Future<void> tapDeleteAndConfirm(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(deleteSessionMenuKey(id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett')); // the menu item opens the dialog
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteSessionConfirmKey));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting a pending session removes its card (offline)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: const <SessionRecord>[],
        pending: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'pending-1',
            capturedAt: DateTime(2026, 6, 21, 10),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(mySessionCard('pending-1')), findsOneWidget);

    await tapDeleteAndConfirm(tester, 'pending-1');

    expect(find.byKey(mySessionCard('pending-1')), findsNothing);
    expect(find.byKey(noSessionsKey), findsOneWidget);
  });

  testWidgets('deleting a synced session removes its card', (tester) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'synced-1',
            capturedAt: DateTime(2026, 6, 21, 10),
          ),
        ],
        pending: const <SessionRecord>[],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(mySessionCard('synced-1')), findsOneWidget);

    await tapDeleteAndConfirm(tester, 'synced-1');

    expect(find.byKey(mySessionCard('synced-1')), findsNothing);
  });

  testWidgets('cancelling the delete dialog keeps the session', (tester) async {
    await tester.pumpWidget(
      _app(
        synced: const <SessionRecord>[],
        pending: <SessionRecord>[
          _recordFor(ProgramCatalogue.airPistol10m, id: 'pending-1'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(deleteSessionMenuKey('pending-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byKey(mySessionCard('pending-1')), findsOneWidget);
  });

  testWidgets('the sync-error banner can be dismissed', (tester) async {
    await tester.pumpWidget(
      _appWith(
        repository: _ThrowingSessionRepository(),
        pending: <SessionRecord>[
          _recordFor(ProgramCatalogue.airPistol10m, id: 'pending-1'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(syncErrorBannerKey), findsOneWidget);

    await tester.tap(find.byKey(syncErrorDismissKey));
    await tester.pumpAndSettle();

    // The notice is gone; the local session stays in place.
    expect(find.byKey(syncErrorBannerKey), findsNothing);
    expect(find.byKey(mySessionCard('pending-1')), findsOneWidget);
  });

  testWidgets('shows no sync-error banner when the cloud read succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'synced-1',
            capturedAt: DateTime(2026, 6, 20),
          ),
        ],
        pending: const <SessionRecord>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(syncErrorBannerKey), findsNothing);
    expect(find.byKey(mySessionCard('synced-1')), findsOneWidget);
  });

  testWidgets('renders a row per entry with program, score and weapon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'synced-1',
            weaponName: 'My pistol',
            capturedAt: DateTime(2026, 6, 20, 10),
          ),
        ],
        pending: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.finpistol25m,
            id: 'pending-1',
            capturedAt: DateTime(2026, 6, 21, 10),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // One card per entry.
    expect(find.byKey(mySessionCard('synced-1')), findsOneWidget);
    expect(find.byKey(mySessionCard('pending-1')), findsOneWidget);

    // Program names and a score line are shown.
    expect(find.text('10 m Air Pistol'), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsOneWidget);
    // Both programs are 60 centre shots -> 600 / 600 with 60 inner tens, one
    // score line per card.
    expect(find.text('600 / 600 · 60×X'), findsNWidgets(2));
    // The weapon name appears for the synced entry that has one.
    expect(find.text('My pistol'), findsOneWidget);
  });

  testWidgets('shows the not-synced badge only on pending entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'synced-1',
            capturedAt: DateTime(2026, 6, 20),
          ),
        ],
        pending: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.airPistol10m,
            id: 'pending-1',
            capturedAt: DateTime(2026, 6, 21),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one badge — on the pending card, not the synced one.
    expect(find.byKey(notSyncedBadgeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(mySessionCard('pending-1')),
        matching: find.byKey(notSyncedBadgeKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(mySessionCard('synced-1')),
        matching: find.byKey(notSyncedBadgeKey),
      ),
      findsNothing,
    );
    expect(find.text('Ikke synkronisert'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(synced: const <SessionRecord>[], pending: const <SessionRecord>[]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(noSessionsKey), findsOneWidget);
    expect(find.text('Ingen lagrede økter ennå'), findsOneWidget);
    // No session cards are rendered in the empty state.
    expect(find.byType(Card), findsNothing);
    // The friendly empty state carries a hint and a "Velg program" call to
    // action so a first-time shooter knows what to do next.
    expect(find.text('Fullfør en økt for å se den her.'), findsOneWidget);
    expect(find.byKey(pickProgramButtonKey), findsOneWidget);
    expect(find.text('Velg program'), findsOneWidget);
  });

  testWidgets(
    'a session enqueued after the list is shown appears without reopening',
    (tester) async {
      // The bug (spec 0026): a just-completed session did not show until the
      // screen was reopened, because the list was a one-shot store read. Mount
      // the screen empty, enqueue a completed session onto the live queue while
      // it is on screen, and assert the row (and its pending badge) appears
      // with no remount. Signed out, so the enqueued record stays pending (its
      // flush no-ops) and the "Ikke synkronisert" badge is shown.
      final repository = InMemorySessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MySessionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // First shown: the empty state, no card.
      expect(find.byKey(noSessionsKey), findsOneWidget);
      expect(find.byType(Card), findsNothing);

      // A session completes and is enqueued onto the live upload queue.
      final record = _recordFor(
        ProgramCatalogue.airPistol10m,
        id: 'fresh-1',
        capturedAt: DateTime(2026, 6, 23, 12),
      );
      await container.read(uploadQueueProvider.notifier).enqueue(record);
      await tester.pumpAndSettle();

      // The row appears immediately — no reopen — with its pending badge.
      expect(find.byKey(noSessionsKey), findsNothing);
      expect(find.byKey(mySessionCard('fresh-1')), findsOneWidget);
      expect(find.text('10 m Air Pistol'), findsOneWidget);
      expect(find.text('600 / 600 · 60×X'), findsOneWidget);
      expect(find.byKey(notSyncedBadgeKey), findsOneWidget);
      expect(find.text('Ikke synkronisert'), findsOneWidget);
    },
  );

  testWidgets(
    'a local pending session shows even while the cloud read hangs',
    (tester) async {
      // The deployed-app defect: in the real app `sessionRepositoryProvider`
      // is the Supabase-backed repository, whose `list()` hits hosted Supabase.
      // If that read is slow or hangs (a paused free-tier project, offline, a
      // table that stalls), a list that AWAITS it would stay loading forever
      // and the user's just-completed LOCAL session would never appear. Mount
      // the screen signed in, with a repository whose `list()` NEVER completes
      // and a completed session already on the live upload queue, and assert
      // the local row (with its pending badge) shows promptly — without
      // `list()` ever completing. The cloud read is a non-blocking enhancement.
      final repository = _HangingSessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      // A completed session is already waiting on the live upload queue (signed
      // out, so its flush no-ops and it stays pending — "Ikke synkronisert").
      final record = _recordFor(
        ProgramCatalogue.airPistol10m,
        id: 'local-1',
        capturedAt: DateTime(2026, 6, 23, 12),
      );
      await container.read(uploadQueueProvider.notifier).enqueue(record);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MySessionsScreen()),
        ),
      );
      // Just pump frames — never settle, because the hung `list()` would make
      // `pumpAndSettle` time out. The local row must already be on screen.
      await tester.pump();
      await tester.pump();

      // The cloud read is still pending — yet the local session is shown.
      expect(repository.listCompleted, isFalse);
      expect(find.byKey(noSessionsKey), findsNothing);
      expect(find.byKey(mySessionCard('local-1')), findsOneWidget);
      expect(find.text('10 m Air Pistol'), findsOneWidget);
      expect(find.text('600 / 600 · 60×X'), findsOneWidget);
      expect(find.byKey(notSyncedBadgeKey), findsOneWidget);
      expect(find.text('Ikke synkronisert'), findsOneWidget);

      // Release the hung read so the container can dispose cleanly.
      repository.release();
    },
  );

  testWidgets('tapping a row opens the detail scorecard with the breakdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[
          _recordFor(
            ProgramCatalogue.finpistol25m,
            id: 'fin-1',
            capturedAt: DateTime(2026, 6, 21),
          ),
        ],
        pending: const <SessionRecord>[],
      ),
    );
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    await tester.tap(find.byKey(mySessionCard('fin-1')));
    await tester.pumpAndSettle();

    // The read-only scorecard appears with the per-series (skive) breakdown.
    expect(find.byKey(sessionCompleteKey), findsOneWidget);
    // Finpistol precision = 6 series, duel = 6 series -> the first precision
    // series reads as a ring-50 skive with five inner tens (five centre shots).
    expect(find.byKey(seriesResultRow(0, 0)), findsOneWidget);
    expect(
      find.bySemanticsLabel('Serie 1: 50 av 50, 5 indre tiere'),
      findsWidgets,
    );

    handle.dispose();
  });

  testWidgets('an unresolvable program shows a graceful message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        synced: <SessionRecord>[_unresolvableRecord(id: 'broken-1')],
        pending: const <SessionRecord>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mySessionCard('broken-1')));
    await tester.pumpAndSettle();

    // No crash: the detail view shows the graceful message and no scorecard.
    expect(find.byKey(unreadableSessionKey), findsOneWidget);
    expect(find.text('Kan ikke vise denne økta'), findsOneWidget);
    expect(find.byKey(sessionCompleteKey), findsNothing);
  });
}

/// A [SessionRepository] whose [list] never completes until [release] is called
/// — a stand-in for a slow or hanging hosted Supabase read. [upload] succeeds,
/// so it never interferes with the queue under test.
class _HangingSessionRepository implements SessionRepository {
  final Completer<List<SessionRecord>> _completer =
      Completer<List<SessionRecord>>();

  /// Whether the hung [list] future has resolved.
  bool listCompleted = false;

  @override
  Future<void> upload(SessionRecord record) async {}

  @override
  Future<List<SessionRecord>> list() {
    final future = _completer.future;
    unawaited(future.then((_) => listCompleted = true));
    return future;
  }

  @override
  Future<void> deleteById(String id) async {}

  /// Completes the hung [list] read (with no synced records), so the test's
  /// container can dispose cleanly.
  void release() {
    if (!_completer.isCompleted) {
      _completer.complete(const <SessionRecord>[]);
    }
  }
}
