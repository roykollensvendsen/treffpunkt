// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for saving and resuming a felt round (spec 0081).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

// A saved round with one inner hit on hare (hold 1), the other holds empty.
FeltSessionSnapshot _savedHareInner(FeltShooterGroup group) =>
    FeltSessionSnapshot(
      group: group,
      currentHold: 0,
      holds: <List<FeltPlacedShot>>[
        const <FeltPlacedShot>[
          FeltPlacedShot(dx: 38.6, dy: 97.9, figureIndex: 0, inner: true),
        ],
        for (var i = 1; i < 8; i++) const <FeltPlacedShot>[],
      ],
    );

void main() {
  const hareFrac = Offset(38.6 / 151, 97.9 / 145);

  Widget appWith(FeltSessionStore store, Widget home) => ProviderScope(
    overrides: [feltSessionStoreProvider.overrideWithValue(store)],
    child: MaterialApp(home: home),
  );

  Future<void> tapRecorder(WidgetTester tester, Offset frac) async {
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(frac.dx * rect.width, frac.dy * rect.height),
    );
    await tester.pump();
  }

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('placing a shot saves the in-progress round (spec 0081)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await tester.pumpWidget(appWith(store, const FeltRecordScreen()));
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();
    await tapRecorder(tester, hareFrac);

    final saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.group, FeltShooterGroup.one);
    expect(saved.holds[0].length, 1);
    expect(saved.holds[0][0].inner, isTrue);
  });

  testWidgets('a saved round is restored on a fresh mount (spec 0081)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await tester.pumpWidget(
      appWith(
        store,
        FeltRecordScreen(restored: _savedHareInner(FeltShooterGroup.one)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Inner 1'), findsOneWidget);
    expect(find.textContaining('Totalt så langt: 3 poeng'), findsOneWidget);
  });

  testWidgets('finishing the round clears the store (spec 0081)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await tester.pumpWidget(appWith(store, const FeltRecordScreen()));
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.two)));
    await tester.pumpAndSettle();
    await tapRecorder(tester, hareFrac);
    expect(await store.load(), isNotNull);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();

    expect(find.byKey(feltScorecardKey), findsOneWidget);
    expect(await store.load(), isNull);
  });

  testWidgets('the course preview resumes and discards a saved round (0081)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await store.save(_savedHareInner(FeltShooterGroup.two));
    await tester.pumpWidget(appWith(store, const FeltCourseScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(feltResumeCardKey), findsOneWidget);
    expect(find.textContaining('Gruppe 2'), findsWidgets);

    // Resume restores the round with its score.
    await tester.tap(find.byKey(feltResumeCardKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inner 1'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Discard clears the store and removes the card.
    await tester.tap(find.byKey(feltDiscardCardKey));
    await tester.pumpAndSettle();
    expect(find.byKey(feltResumeCardKey), findsNothing);
    expect(await store.load(), isNull);
  });
}
