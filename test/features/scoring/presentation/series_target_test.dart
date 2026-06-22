// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the interactive series target: placing several shots, moving
// a placed one, zooming, and rendering a reduced-ring face.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

final TargetGeometry _airRifleGeometry =
    ProgramCatalogue.airRifle10m.stages.first.geometry;

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byKey(seriesTargetKey)),
        listen: false,
      );

  int placedCount(ProviderContainer container) =>
      container.read(sessionProvider).current!.placedCount;

  testWidgets('tapping places shots one after another', (tester) async {
    await tester.pumpWidget(_app());
    final container = containerOf(tester);
    expect(placedCount(container), 0);

    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();
    expect(placedCount(container), 1);

    final rect = tester.getRect(find.byKey(seriesTargetKey));
    await tester.tapAt(rect.center + const Offset(10, 0));
    await tester.pump();
    expect(placedCount(container), 2);
  });

  testWidgets('long-press picks up a placed shot and dragging moves it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final container = containerOf(tester);

    await tester.tap(find.byKey(seriesTargetKey)); // centre shot
    await tester.pump();

    final centre = tester.getCenter(find.byKey(seriesTargetKey));
    final rect = tester.getRect(find.byKey(seriesTargetKey));
    final scale = (rect.width / 2) / _airRifleGeometry.maxScoringRadiusMm;

    final gesture = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(container.read(sessionProvider).isDragging, isTrue);

    await gesture.moveTo(centre + Offset(5 * scale, 0));
    await tester.pump();
    expect(
      container.read(sessionProvider).current!.shots.single.dxMm,
      closeTo(5, 0.5),
    );

    await gesture.up();
    await tester.pump();
    expect(container.read(sessionProvider).isDragging, isFalse);
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
    final scale = (rect.width / 2) / _airRifleGeometry.maxScoringRadiusMm;

    final gesture = await tester.startGesture(centre + Offset(5 * scale, 0));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(container.read(sessionProvider).isDragging, isTrue);

    await gesture.up();
    await tester.pump();
    final shot = container.read(sessionProvider).current!.shots.single;
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
    const rapidProgram = ProgramDefinition(
      name: 'Rapid',
      discipline: Discipline.pistol,
      stages: <StageDefinition>[
        StageDefinition(
          name: 'Duell',
          geometry: TargetGeometry.pistol25mRapid(),
          shotsPerSeries: 5,
          seriesCount: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProgramDefinitionProvider.overrideWithValue(rapidProgram),
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
      currentProgramDefinitionProvider.overrideWithValue(
        ProgramCatalogue.airRifle10m,
      ),
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
