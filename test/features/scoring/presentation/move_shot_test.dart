// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for picking up and dragging a placed shot (spec 0002).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scoring_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/target_canvas.dart';

void main() {
  testWidgets('long-press picks up the shot and dragging moves it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    // Place a shot in the centre (maximum score).
    await tester.tap(find.byKey(targetGestureKey));
    await tester.pumpAndSettle();
    expect(find.text('10.9'), findsOneWidget);

    final centre = tester.getCenter(find.byKey(targetGestureKey));
    final rect = tester.getRect(find.byKey(targetGestureKey));
    final scale = (rect.width / 2) / 25.0; // pixels per millimetre

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(targetGestureKey)),
      listen: false,
    );

    // Long-press on the marker to pick it up.
    final gesture = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(container.read(shotPlacementProvider).isDragging, isTrue);

    // Drag 5 mm to the right -> distance 5 mm -> decimal score 9.0.
    await gesture.moveTo(centre + Offset(5 * scale, 0));
    await tester.pump();
    expect(find.text('9.0'), findsOneWidget);

    // Release -> no longer dragging, the shot stays put.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(shotPlacementProvider).isDragging, isFalse);
    expect(find.text('9.0'), findsOneWidget);
  });
}

Widget _app() => const ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: TargetCanvas(geometry: TargetGeometry.airRifle10m()),
    ),
  ),
);
