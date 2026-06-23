// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the reusable build-version footer (spec 0028).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';

void main() {
  testWidgets('shows the build label under its key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BuildVersionLabel())),
    );

    final label = find.byKey(buildVersionKey);
    expect(label, findsOneWidget);
    // The compile-time fallback in a test build is "build dev".
    expect(tester.widget<Text>(label).data, 'build dev');
  });
}
