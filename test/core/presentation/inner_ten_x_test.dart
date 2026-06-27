// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('innerTenScoreText', () {
    testWidgets('shows the count and a ringed X when there are inner tens', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) =>
                innerTenScoreText(context: context, lead: '600', innerTens: 60),
          ),
        ),
      );

      // The lead, separator and count render as text; the X is drawn (a
      // widget), so it is not part of the string — it must be the ringed badge.
      expect(
        find.textContaining('600 · 60', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(InnerTenX), findsOneWidget);
      // The badge is literally a ringed "X", not a multiplication "×X".
      expect(find.text('X'), findsOneWidget);
      expect(find.textContaining('×', findRichText: true), findsNothing);
    });

    testWidgets('is a plain total with no badge when there are no inner tens', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) =>
                innerTenScoreText(context: context, lead: '94', innerTens: 0),
          ),
        ),
      );

      expect(find.text('94'), findsOneWidget);
      expect(find.byType(InnerTenX), findsNothing);
    });
  });

  testWidgets('InnerTenX draws a circular border around the X', (tester) async {
    await tester.pumpWidget(
      host(const InnerTenX(fontSize: 18, color: Colors.black)),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isNotNull);
    expect(find.text('X'), findsOneWidget);
  });
}
