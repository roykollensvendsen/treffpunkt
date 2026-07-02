// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for recording a NorgesFelt session (spec 0080).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/felt/data/felt_group_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

void main() {
  // Hold 1's hare inner-zone centre as a fraction of the hold (151×145 px).
  const hareFrac = Offset(38.6 / 151, 97.9 / 145);

  Future<void> tapRecorder(WidgetTester tester, Offset frac) async {
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(frac.dx * rect.width, frac.dy * rect.height),
    );
    await tester.pump();
  }

  testWidgets('pick a group, place a shot, score updates (spec 0080)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeltRecordScreen())),
    );
    // Only gruppe 1 and 2 are offered — gruppe 3 is not shot (spec 0088).
    expect(
      find.byKey(feltGroupButtonKey(FeltShooterGroup.two)),
      findsOneWidget,
    );
    expect(
      find.byKey(feltGroupButtonKey(FeltShooterGroup.three)),
      findsNothing,
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();

    // A hit in the hare's inner zone scores treff + figur = 2; the inner hit
    // is shown as the ringed-X tiebreak count, not as a point (spec 0085).
    await tapRecorder(tester, hareFrac);
    expect(
      find.textContaining(
        'Treff 1 · Figur 1  =  2 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Totalt så langt: 2 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // The inner count is drawn with the same ringed X as the ring programs'
    // inner tens (spec 0023) — one on the hold line, one on the total.
    expect(find.byType(InnerTenX), findsNWidgets(2));
  });

  testWidgets('a hold-2 stripe scores as one figure, middle inner (0086)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeltRecordScreen())),
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neste'));
    await tester.pumpAndSettle();

    // Hold 2 (247×151): the top stripe's left square centre (21, 20.5) and
    // middle square centre (57.5, 20.5). One figure, the middle is inner —
    // treff 2 + figur 1 = 3 points and a ringed-X count of 1 (specs
    // 0085/0086).
    await tapRecorder(tester, const Offset(21 / 247, 20.5 / 151));
    await tapRecorder(tester, const Offset(57.5 / 247, 20.5 / 151));
    expect(
      find.textContaining(
        'Treff 2 · Figur 1  =  3 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('placing is capped at the group shot count (spec 0080)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeltRecordScreen())),
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();

    for (var i = 0; i < 9; i++) {
      await tapRecorder(tester, hareFrac);
    }
    // Group 1 caps at 6 shots per hold.
    expect(find.textContaining('Skudd 6/6'), findsOneWidget);
  });

  testWidgets('finishing shows the scorecard with a total (spec 0080)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeltRecordScreen())),
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.two)));
    await tester.pumpAndSettle();

    await tapRecorder(tester, hareFrac);
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();

    expect(find.byKey(feltScorecardKey), findsOneWidget);
    // The total renders in the filled result card, like the ring scorecard
    // (spec 0089): the group label, the big points number and the ringed-X
    // inner count (one inner hit on one figure → 2 points · 1 Ⓧ).
    expect(find.textContaining('TOTALT (GRUPPE 2)'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.textContaining('Poeng · 1', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a remembered group skips the picker (spec 0099)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = InMemoryFeltGroupStore(seeded: FeltShooterGroup.two);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feltGroupStoreProvider.overrideWithValue(store),
          initialFeltGroupProvider.overrideWithValue(FeltShooterGroup.two),
        ],
        child: const MaterialApp(home: FeltRecordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Straight to hold 1 with gruppe 2's five shots per hold — no picker.
    expect(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)), findsNothing);
    expect(find.textContaining('Skudd 0/5'), findsOneWidget);

    // «Bytt gruppe» is offered while no shots are placed…
    expect(find.byKey(feltChangeGroupKey), findsOneWidget);
    await tester.tap(find.byKey(feltChangeGroupKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(feltGroupButtonKey(FeltShooterGroup.one)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Skudd 0/6'), findsOneWidget);

    // …and picking persisted the new choice for the next round.
    expect(await store.load(), FeltShooterGroup.one);

    // After the first shot the change action is gone.
    await tapRecorder(tester, hareFrac);
    expect(find.byKey(feltChangeGroupKey), findsNothing);
  });
}
