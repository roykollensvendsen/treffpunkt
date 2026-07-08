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

  group('onCommit (spec 0151)', () {
    Widget commitHost(void Function(Offset, {required bool moved}) onCommit) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: MagnifierOverlay(
                  onCommit: onCommit,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        );

    testWidgets('a tap commits at the release point, not moved', (
      tester,
    ) async {
      Offset? at;
      bool? wasMoved;
      await tester.pumpWidget(
        commitHost((p, {required moved}) {
          at = p;
          wasMoved = moved;
        }),
      );
      final origin = tester.getTopLeft(find.byType(MagnifierOverlay));
      final gesture = await tester.startGesture(origin + const Offset(50, 60));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(at, const Offset(50, 60));
      expect(wasMoved, isFalse);
    });

    testWidgets('a slide commits at the LIFT point, marked moved', (
      tester,
    ) async {
      Offset? at;
      bool? wasMoved;
      await tester.pumpWidget(
        commitHost((p, {required moved}) {
          at = p;
          wasMoved = moved;
        }),
      );
      final origin = tester.getTopLeft(find.byType(MagnifierOverlay));
      final gesture = await tester.startGesture(origin + const Offset(40, 40));
      await tester.pump();
      await gesture.moveTo(origin + const Offset(160, 120));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      // The shot lands where the finger lifted, not where it touched down.
      expect(at, const Offset(160, 120));
      expect(wasMoved, isTrue);
    });

    testWidgets('a pinch commits nothing', (tester) async {
      var commits = 0;
      await tester.pumpWidget(
        commitHost((_, {required moved}) => commits++),
      );
      final centre = tester.getCenter(find.byType(MagnifierOverlay));
      final a = await tester.startGesture(centre + const Offset(-20, 0));
      final b = await tester.startGesture(centre + const Offset(20, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      expect(commits, 0);
    });
  });
}
