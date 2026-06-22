// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the series scoring screen (spec 0006).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';

void main() {
  String totalText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(seriesTotalKey)).data!;

  IconButton sealButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(sealSeriesKey));

  testWidgets('starts with the program name, an empty list and zero total', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    // Once in the app bar title and once in the meta row.
    expect(find.text('10 m Air Rifle'), findsNWidgets(2));
    expect(find.text('0 / 10'), findsOneWidget);
    expect(totalText(tester), '0');
    expect(sealButton(tester).onPressed, isNull);
  });

  testWidgets('placing a shot updates the shots list and the total', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();

    expect(find.text('1 / 10'), findsOneWidget);
    expect(totalText(tester), '10');
  });

  testWidgets('completing the series enables sealing it', (tester) async {
    await tester.pumpWidget(_app());

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(seriesTargetKey));
      await tester.pump();
    }

    expect(find.text('10 / 10'), findsOneWidget);
    expect(totalText(tester), '100');
    expect(sealButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(sealSeriesKey));
    await tester.pump();
    expect(find.text('SERIES TOTAL · COMPLETE'), findsOneWidget);
  });
}

Widget _app() {
  return const ProviderScope(
    child: MaterialApp(home: SeriesScreen(program: Program.airRifle10m)),
  );
}
