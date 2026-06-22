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
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
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

  testWidgets('pinching zooms the target in', (tester) async {
    await tester.pumpWidget(_app());

    final viewer = find.byType(InteractiveViewer);
    expect(viewer, findsOneWidget);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1.0);

    final centre = tester.getCenter(find.byKey(seriesTargetKey));
    final gesture1 = await tester.startGesture(centre - const Offset(20, 0));
    final gesture2 = await tester.startGesture(centre + const Offset(20, 0));
    await tester.pump();
    await gesture1.moveBy(const Offset(-60, 0));
    await gesture2.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture1.up();
    await gesture2.up();
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));
  });

  testWidgets('the zoom buttons zoom in and reset', (tester) async {
    await tester.pumpWidget(_app());
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1.0);

    await tester.tap(find.byKey(const ValueKey<String>('zoomIn')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));

    await tester.tap(find.byKey(const ValueKey<String>('zoomReset')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
  });

  testWidgets('renders a reduced-ring (rapid) face without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProgramProvider.overrideWithValue(
            const Program(
              name: 'Rapid',
              geometry: TargetGeometry.pistol25mRapid(),
              shotsPerSeries: 5,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 400, height: 400, child: SeriesTarget()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(seriesTargetKey), findsOneWidget);
    expect(tester.takeException(), isNull);
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
