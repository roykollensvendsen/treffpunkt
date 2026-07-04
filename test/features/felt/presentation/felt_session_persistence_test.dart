// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for saving and resuming a felt round (specs 0081/0116).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/zoom_controls.dart';
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
    // The restored inner hit shows as the ringed-X tiebreak count, and the
    // corrected total counts treff + figur only (spec 0085).
    expect(
      find.textContaining(
        'Treff 1 · Figur 1  =  2 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Totalt så langt: 2 poeng · 1', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('saving the round clears the store; finishing keeps it (0091)', (
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

    // Finished but not saved: the round is still resumable, never lost.
    expect(find.byKey(feltScorecardKey), findsOneWidget);
    expect(await store.load(), isNotNull);

    // Saving clears the in-progress store.
    await tester.tap(find.byKey(feltSaveRoundKey));
    await tester.pumpAndSettle();
    expect(await store.load(), isNull);
  });

  testWidgets('the hold picture zooms with the shared buttons (0125)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await tester.pumpWidget(appWith(store, const FeltRecordScreen()));
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1.0);

    await tester.tap(find.byKey(zoomInKey));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));

    // A tap at the visual centre after a CENTRED zoom is the same picture
    // point as without zoom (spec 0125): the shot lands where the finger
    // points, and the stored fraction is unaffected by the transform.
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(find.textContaining('Skudd 1/6'), findsOneWidget);

    await tester.tap(find.byKey(zoomResetKey));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
  });

  testWidgets('a pinch zooms without planting a shot (spec 0128)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await tester.pumpWidget(appWith(store, const FeltRecordScreen()));
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));

    // Two fingers land and spread — a pinch. While they are down the page
    // scroll is suspended (spec 0021 parity) so the viewer owns the whole
    // gesture; no shot is planted by the pinch.
    final f1 = await tester.startGesture(rect.center - const Offset(20, 0));
    final f2 = await tester.startGesture(rect.center + const Offset(20, 0));
    await tester.pump();
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await f1.moveBy(const Offset(-60, -10));
    await f2.moveBy(const Offset(60, 10));
    await tester.pump();
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));
    expect(find.textContaining('Skudd 0/6'), findsOneWidget);
    // Released: the page scrolls again.
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );

    // A completed tap still places exactly one shot.
    await tester.tap(find.byKey(zoomResetKey));
    await tester.pump();
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(find.textContaining('Skudd 1/6'), findsOneWidget);
  });

  testWidgets('the course preview no longer offers resume (spec 0116)', (
    tester,
  ) async {
    bigView(tester);
    final store = InMemoryFeltSessionStore();
    await store.save(_savedHareInner(FeltShooterGroup.two));
    await tester.pumpWidget(appWith(store, const FeltCourseScreen()));
    await tester.pumpAndSettle();

    // The single resume card lives on the front page (spec 0116); the
    // course page keeps «Skyt løypa» and the hold previews only.
    expect(find.text('Fortsett felt-økt'), findsNothing);
    expect(find.byKey(feltShootButtonKey), findsOneWidget);
  });
}
