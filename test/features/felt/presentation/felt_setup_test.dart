// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the felt setup step (spec 0092): time, place and weapon
// ride the round from the shared setup form into the saved record.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Skyt løypa runs through the shared setup form (0092)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltHistoryStoreProvider.overrideWithValue(history)],
        child: const MaterialApp(home: FeltCourseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(feltShootButtonKey));
    await tester.pumpAndSettle();

    // The same form the ring programs use: date/time, place, weapon, start.
    expect(find.byKey(dateTimeKey), findsOneWidget);
    expect(find.byKey(placeFieldKey), findsOneWidget);
    expect(find.text('Våpen'), findsOneWidget);
    await tester.enterText(find.byKey(placeFieldKey), 'Løvenskiold');
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    // Then the group picker, and one shot on hold 1.
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
    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();

    // The saved record carries the typed place and the chosen date (0092).
    final saved = await history.load();
    expect(saved.single.session.placeLabel, 'Løvenskiold');
    expect(saved.single.session.capturedAt, isNotNull);
    expect(saved.single.capturedAt, saved.single.session.capturedAt);
  });

  testWidgets('a resumed round keeps its metadata into the record (0092)', (
    tester,
  ) async {
    bigView(tester);
    final history = InMemoryFeltHistoryStore();
    final restored = FeltSessionSnapshot(
      group: FeltShooterGroup.two,
      currentHold: 0,
      capturedAt: DateTime.utc(2026, 7, 2, 18),
      placeLabel: 'Kongsberg',
      weaponName: 'Min revolver',
      holds: <List<FeltPlacedShot>>[
        const <FeltPlacedShot>[
          FeltPlacedShot(dx: 38.6, dy: 97.9, figureIndex: 0, inner: true),
        ],
        for (var i = 1; i < 8; i++) const <FeltPlacedShot>[],
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltHistoryStoreProvider.overrideWithValue(history)],
        child: MaterialApp(home: FeltRecordScreen(restored: restored)),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();

    final saved = await history.load();
    expect(saved.single.capturedAt, DateTime.utc(2026, 7, 2, 18));
    expect(saved.single.session.placeLabel, 'Kongsberg');
    expect(saved.single.session.weaponName, 'Min revolver');
  });
}
