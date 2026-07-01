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
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

FeltSessionRecord _record() => FeltSessionRecord(
  id: 'felt-1',
  capturedAt: DateTime.utc(2026, 7, 1, 12, 30),
  session: FeltSessionSnapshot(
    group: FeltShooterGroup.two,
    currentHold: 0,
    holds: <List<FeltPlacedShot>>[
      const <FeltPlacedShot>[
        FeltPlacedShot(dx: 38.6, dy: 97.9, figureIndex: 0, inner: true),
      ],
      for (var i = 1; i < 8; i++) const <FeltPlacedShot>[],
    ],
  ),
);

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('finishing a felt round adds it to history (spec 0082)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltHistoryStoreProvider.overrideWithValue(history)],
        child: const MaterialApp(home: FeltRecordScreen()),
      ),
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.two)));
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

    final saved = await history.load();
    expect(saved.length, 1);
    expect(saved.single.points, 3); // treff + figur + inner
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
    expect(find.textContaining('3 poeng'), findsWidgets);

    await tester.tap(find.byKey(feltSessionCard('felt-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(feltScorecardKey), findsOneWidget);
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
