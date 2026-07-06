// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the shared load-failure state: a short notice over a
// «Prøv igjen» button that fires the caller's retry callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/error_retry.dart';

void main() {
  testWidgets('shows the failure notice and a retry button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ErrorRetry(onRetry: () {})),
      ),
    );

    expect(find.text('Kunne ikke hente konkurransene.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Prøv igjen'), findsOneWidget);
  });

  testWidgets('tapping «Prøv igjen» fires the retry callback', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ErrorRetry(onRetry: () => retries++)),
      ),
    );

    await tester.tap(find.text('Prøv igjen'));
    expect(retries, 1);
  });
}
