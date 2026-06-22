// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the interactive series target (specs 0004/0006): placing
// several shots and moving a placed one.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/presentation/series_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byKey(seriesTargetKey)),
        listen: false,
      );

  testWidgets('tapping places shots one after another', (tester) async {
    await tester.pumpWidget(_app());
    final container = containerOf(tester);
    expect(container.read(seriesProvider).series.placedCount, 0);

    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();
    expect(container.read(seriesProvider).series.placedCount, 1);

    final rect = tester.getRect(find.byKey(seriesTargetKey));
    await tester.tapAt(rect.center + const Offset(10, 0));
    await tester.pump();
    expect(container.read(seriesProvider).series.placedCount, 2);
  });

  testWidgets('long-press picks up a placed shot and dragging moves it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final container = containerOf(tester);

    // Place a shot in the centre (maximum score).
    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();

    final centre = tester.getCenter(find.byKey(seriesTargetKey));
    final rect = tester.getRect(find.byKey(seriesTargetKey));
    // Pixels per millimetre, derived from the air-rifle geometry.
    final scale =
        (rect.width / 2) / Program.airRifle10m.geometry.maxScoringRadiusMm;

    final gesture = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(container.read(seriesProvider).isDragging, isTrue);

    await gesture.moveTo(centre + Offset(5 * scale, 0));
    await tester.pump();
    expect(
      container.read(seriesProvider).series.shots.single.dxMm,
      closeTo(5, 0.5),
    );

    await gesture.up();
    await tester.pump();
    expect(container.read(seriesProvider).isDragging, isFalse);
  });

  testWidgets('long-press near a marker without dragging leaves it put', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final container = containerOf(tester);

    await tester.tap(find.byKey(seriesTargetKey)); // shot at the centre
    await tester.pump();

    final centre = tester.getCenter(find.byKey(seriesTargetKey));
    final rect = tester.getRect(find.byKey(seriesTargetKey));
    final scale =
        (rect.width / 2) / Program.airRifle10m.geometry.maxScoringRadiusMm;

    // Long-press ~5 mm off the marker (inside the 6 mm pick-up radius), then
    // release without moving: the shot must not jump to the press point.
    final gesture = await tester.startGesture(centre + Offset(5 * scale, 0));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(container.read(seriesProvider).isDragging, isTrue);

    await gesture.up();
    await tester.pump();
    final shot = container.read(seriesProvider).series.shots.single;
    expect(shot.dxMm, closeTo(0, 0.5));
    expect(shot.dyMm, closeTo(0, 0.5));
  });
}

Widget _app() {
  return ProviderScope(
    overrides: [
      currentProgramProvider.overrideWithValue(Program.airRifle10m),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 400, height: 400, child: SeriesTarget()),
        ),
      ),
    ),
  );
}
