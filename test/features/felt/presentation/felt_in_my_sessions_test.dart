// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for finished felt rounds landing in "Mine økter" (spec 0082).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

import '../../../support/records.dart';

FeltSessionRecord _record() => feltSessionRecord(
  id: 'felt-1',
  capturedAt: DateTime.utc(2026, 7, 1, 12, 30),
  group: FeltShooterGroup.two,
  holdCount: 8,
  shot: const FeltPlacedShot(dx: 38.6, dy: 97.9, figureIndex: 0, inner: true),
);

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('an Asker+ round is labelled with its course (spec 0145)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[
      feltSessionRecord(
        id: 'felt-asker',
        capturedAt: DateTime.utc(2026, 7, 7, 18),
        holdCount: 10,
        courseId: 'norgesfelt-asker-plus',
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltHistoryStoreProvider.overrideWithValue(history),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
          feltSessionRepositoryProvider.overrideWithValue(
            InMemoryFeltSessionRepository(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NorgesFelt Asker+'), findsOneWidget);
    expect(find.text('NorgesFelt-løype 2026'), findsNothing);
  });

  testWidgets('finishing a felt round adds it to history (spec 0082)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltHistoryStoreProvider.overrideWithValue(history)],
        child: const MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.two),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(38.6 / 151 * rect.width, 97.9 / 145 * rect.height),
    );
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();

    // Fullfør alone saves nothing — the save is the explicit button (0091).
    expect(await history.load(), isEmpty);

    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();

    final saved = await history.load();
    expect(saved.length, 1);
    // Treff + figur = 2; the inner hit is the tiebreaker, no point (0085).
    expect(saved.single.points, 2);
    expect(saved.single.tally.inner, 1);
    expect(find.text('Økta er lagret.'), findsOneWidget);
  });

  testWidgets('walking back and forth never duplicates the round (0091)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltHistoryStoreProvider.overrideWithValue(history)],
        child: const MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.two),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(38.6 / 151 * rect.width, 97.9 / 145 * rect.height),
    );
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }

    // The domain expert's exact walk: Fullfør → tilbake → Fullfør → save.
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();

    // Exactly one saved round — and even a second save press (the screen is
    // the test's root route, so it cannot pop away) upserts by the round's
    // stable id instead of duplicating.
    expect(await history.load(), hasLength(1));
    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();
    expect(await history.load(), hasLength(1));
  });

  testWidgets('a saved felt round shows in Mine økter and opens its card', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[_record()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltHistoryStoreProvider.overrideWithValue(history),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(feltSessionCard('felt-1')), findsOneWidget);
    expect(find.textContaining('NorgesFelt-løype 2026'), findsWidgets);
    // Points and the ringed-X tiebreak count, like the ring programs (0085).
    expect(
      find.textContaining('2 poeng · 1', findRichText: true),
      findsWidgets,
    );

    await tester.tap(find.byKey(feltSessionCard('felt-1')));
    await tester.pumpAndSettle();
    // A taller viewport so the lazy scorecard builds all 8 hold pictures.
    tester.view.physicalSize = const Size(600, 6000);
    await tester.pumpAndSettle();
    expect(find.byKey(feltScorecardKey), findsOneWidget);
    // The read-only detail view carries no save button (spec 0091 req 5).
    expect(find.byKey(feltSaveRoundKey), findsNothing);
    // The stored shots are drawn on the hold pictures (spec 0105): one
    // picture per hold, the single inner hare hit marked on hold 1.
    expect(find.byType(FeltHoldShotsView), findsNWidgets(8));
    expect(find.byType(FeltShotMarker), findsOneWidget);
  });

  testWidgets("the felt card shows the round's place and weapon (0092)", (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    final round = FeltSessionRecord(
      id: 'felt-2',
      capturedAt: DateTime.utc(2026, 7, 2, 18),
      session: FeltSessionSnapshot(
        group: FeltShooterGroup.one,
        currentHold: 0,
        placeLabel: 'Kongsberg',
        weaponName: 'Min revolver',
        holds: <List<FeltPlacedShot>>[
          const <FeltPlacedShot>[
            FeltPlacedShot(dx: 1, dy: 1, figureIndex: 0),
          ],
          for (var i = 1; i < 8; i++) const <FeltPlacedShot>[],
        ],
      ),
    );
    await history.save(<FeltSessionRecord>[round]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltHistoryStoreProvider.overrideWithValue(history),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Kongsberg'), findsOneWidget);
    expect(find.text('Min revolver'), findsOneWidget);

    // The detail view captions the round with them too.
    await tester.tap(find.byKey(feltSessionCard('felt-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kongsberg'), findsOneWidget);
    expect(find.textContaining('Min revolver'), findsOneWidget);
  });

  Future<void> tapDeleteAndConfirm(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(deleteSessionMenuKey(id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett')); // the menu item opens the dialog
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteSessionConfirmKey));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting a local felt round removes it (spec 0089)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[_record()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltHistoryStoreProvider.overrideWithValue(history),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(feltSessionCard('felt-1')), findsOneWidget);

    await tapDeleteAndConfirm(tester, 'felt-1');

    // The card is gone and the round is removed from the device.
    expect(find.byKey(feltSessionCard('felt-1')), findsNothing);
    expect(await history.load(), isEmpty);
  });

  testWidgets('deleting a synced felt round also clears the account (0089)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[_record()]);
    final repository = InMemoryFeltSessionRepository();
    await repository.upload(_record());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltHistoryStoreProvider.overrideWithValue(history),
          feltSessionRepositoryProvider.overrideWithValue(repository),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(feltSessionCard('felt-1')), findsOneWidget);

    await tapDeleteAndConfirm(tester, 'felt-1');

    // Removed from the account and the device; the card is gone.
    expect(find.byKey(feltSessionCard('felt-1')), findsNothing);
    expect(await repository.list(), isEmpty);
    expect(await history.load(), isEmpty);
  });

  testWidgets('a cloud-only felt round shows in Mine økter (spec 0083)', (
    tester,
  ) async {
    bigView(tester);
    final repository = InMemoryFeltSessionRepository();
    await repository.upload(_record()); // only in the cloud, not local history

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltSessionRepositoryProvider.overrideWithValue(repository),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(
            InMemoryPendingUploadsStore(),
          ),
        ],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(feltSessionCard('felt-1')), findsOneWidget);
  });
}
