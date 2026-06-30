// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the field-shooting recorder (spec 0068): counting hits and
// inner hits per hold updates the running total; inner hits are capped at hits;
// the count cannot go below zero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_session.dart';
import 'package:treffpunkt/features/felt/presentation/felt_screen.dart';

void main() {
  Widget app() => const MaterialApp(home: FeltScreen(feltClass: FeltClass.fin));

  String valueOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  testWidgets('counting hits updates the total', (tester) async {
    await tester.pumpWidget(app());
    expect(find.textContaining('Finfelt'), findsOneWidget);
    expect(
      valueOf(tester, feltTotalKey),
      'Totalt: 0 / 60 treff  ·  0 innertreff',
    );

    // Three hits on hold 1.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(feltHitsPlusKey(0)));
      await tester.pump();
    }
    // Two hits on hold 2.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(feltHitsPlusKey(1)));
      await tester.pump();
    }

    expect(valueOf(tester, feltHoldHitsKey(0)), '3');
    expect(valueOf(tester, feltHoldHitsKey(1)), '2');
    expect(
      valueOf(tester, feltTotalKey),
      'Totalt: 5 / 60 treff  ·  0 innertreff',
    );
  });

  testWidgets('inner hits are capped at the hold hits', (tester) async {
    await tester.pumpWidget(app());

    // No hits yet → inner stays at 0.
    await tester.tap(find.byKey(feltInnerPlusKey(0)));
    await tester.pump();
    expect(valueOf(tester, feltHoldInnerKey(0)), '0');

    // One hit, then inner can reach 1 but not 2.
    await tester.tap(find.byKey(feltHitsPlusKey(0)));
    await tester.pump();
    await tester.tap(find.byKey(feltInnerPlusKey(0)));
    await tester.pump();
    await tester.tap(find.byKey(feltInnerPlusKey(0)));
    await tester.pump();
    expect(valueOf(tester, feltHoldInnerKey(0)), '1');
    expect(
      valueOf(tester, feltTotalKey),
      'Totalt: 1 / 60 treff  ·  1 innertreff',
    );
  });

  testWidgets('hits do not go below zero', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(feltHitsMinusKey(0)));
    await tester.pump();
    expect(valueOf(tester, feltHoldHitsKey(0)), '0');
  });
}
