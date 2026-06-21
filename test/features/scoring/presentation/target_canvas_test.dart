// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the interactive target canvas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/target_canvas.dart';

void main() {
  testWidgets('starts with a prompt and no score', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Tap the target'), findsOneWidget);
  });

  testWidgets('tapping the centre shows the maximum score 10.9', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(targetGestureKey));
    await tester.pumpAndSettle();

    expect(find.text('10.9'), findsOneWidget);
    expect(find.text('Tap the target'), findsNothing);
  });
}

Widget _app() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: TargetCanvas(geometry: TargetGeometry.airRifle10m()),
      ),
    ),
  );
}
