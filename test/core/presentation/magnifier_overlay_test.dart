// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the shot-placement magnifier loupe (spec 0150).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/magnifier_overlay.dart';

void main() {
  Widget host({bool enabled = true}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: MagnifierOverlay(
            enabled: enabled,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    ),
  );

  testWidgets('a single press shows the loupe and release hides it', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.byType(RawMagnifier), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MagnifierOverlay)),
    );
    await tester.pump();
    expect(find.byType(RawMagnifier), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.byType(RawMagnifier), findsNothing);
  });

  testWidgets('the loupe follows the finger as it drags', (tester) async {
    await tester.pumpWidget(host());
    final origin = tester.getTopLeft(find.byType(MagnifierOverlay));

    final gesture = await tester.startGesture(origin + const Offset(80, 200));
    await tester.pump();
    final first = tester.getTopLeft(find.byType(RawMagnifier));

    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    final second = tester.getTopLeft(find.byType(RawMagnifier));

    // Moving the finger right moves the loupe right.
    expect(second.dx, greaterThan(first.dx));
    await gesture.up();
  });

  testWidgets('a two-finger pinch raises no loupe (spec 0150)', (tester) async {
    await tester.pumpWidget(host());
    final centre = tester.getCenter(find.byType(MagnifierOverlay));

    final first = await tester.startGesture(centre + const Offset(-20, 0));
    await tester.pump();
    expect(find.byType(RawMagnifier), findsOneWidget);

    // A second finger down (a pinch) hides the loupe.
    final second = await tester.startGesture(centre + const Offset(20, 0));
    await tester.pump();
    expect(find.byType(RawMagnifier), findsNothing);

    await first.up();
    await second.up();
  });

  testWidgets('a disabled overlay never shows a loupe', (tester) async {
    await tester.pumpWidget(host(enabled: false));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MagnifierOverlay)),
    );
    await tester.pump();
    expect(find.byType(RawMagnifier), findsNothing);
    await gesture.up();
  });
}
