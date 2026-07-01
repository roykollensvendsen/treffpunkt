// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for recording a NorgesFelt session (spec 0080).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
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
    await tester.tap(find.byKey(feltGroupButtonKey(FeltShooterGroup.one)));
    await tester.pumpAndSettle();

    // A hit in the hare's inner zone scores treff + figur + inner = 3.
    await tapRecorder(tester, hareFrac);
    expect(
      find.textContaining('Treff 1 · Figur 1 · Inner 1  =  3 poeng'),
      findsOneWidget,
    );
    expect(find.textContaining('Totalt så langt: 3 poeng'), findsOneWidget);
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
    expect(find.textContaining('3 poeng'), findsWidgets);
  });
}
