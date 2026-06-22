// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the guided session screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

// A small two-stage program on two faces, for the advance test.
const ProgramDefinition _twoStage = ProgramDefinition(
  name: 'Two-stage',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
    StageDefinition(
      name: 'B',
      geometry: TargetGeometry.pistol25mRapid(),
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
  ],
);

// A single 5-shot precision series (inner-ten geometry), so a centre shot
// scores ring 10 and counts as an inner ten — used to pin the spoken inner-ten
// phrasing and the per-shot row labels.
const ProgramDefinition _precision5 = ProgramDefinition(
  name: 'Precision-5',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'P',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 5,
      seriesCount: 1,
    ),
  ],
);

void main() {
  String totalText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(seriesTotalKey)).data!;
  IconButton sealButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(sealSeriesKey));

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();
  }

  testWidgets('starts with the program name, a header and a zero total', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));

    expect(find.text('10 m Air Rifle'), findsOneWidget); // app bar only
    expect(find.byKey(stageProgressKey), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
    expect(totalText(tester), '0');
    expect(sealButton(tester).onPressed, isNull);
  });

  testWidgets('placing a shot updates the shots list and the total', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
    await tapTarget(tester);

    expect(find.text('1 / 10'), findsOneWidget);
    expect(totalText(tester), '10');
  });

  testWidgets('completing the only series finishes the session', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
    for (var i = 0; i < 10; i++) {
      await tapTarget(tester);
    }
    expect(find.text('10 / 10'), findsOneWidget);
    expect(sealButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(sealSeriesKey));
    await tester.pumpAndSettle();
    expect(find.byKey(sessionCompleteKey), findsOneWidget);
  });

  testWidgets('advances through stages, switching the face, then finishes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_twoStage));

    expect(find.text('A'), findsOneWidget); // stage A name in the header
    await tapTarget(tester);
    await tapTarget(tester);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byKey(sealSeriesKey)); // advance to stage B
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);

    await tapTarget(tester);
    await tapTarget(tester);
    await tester.tap(find.byKey(sealSeriesKey)); // finish
    await tester.pumpAndSettle();
    expect(find.byKey(sessionCompleteKey), findsOneWidget);
  });

  // Shoots the one-series air-rifle program to its end and reaches the
  // scorecard, so the metadata caption can be asserted.
  Future<void> completeAirRifle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tapTarget(tester);
    }
    await tester.tap(find.byKey(sealSeriesKey));
    await tester.pumpAndSettle();
  }

  group('responsive layout', () {
    Future<void> pumpAt(WidgetTester tester, Size logicalSize) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = logicalSize;
      // Restore the default test surface after driving a custom size.
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
      await tester.pumpAndSettle();
    }

    testWidgets('stacks the target above the totals on a narrow surface', (
      tester,
    ) async {
      await pumpAt(tester, const Size(420, 900));

      final target = tester.getRect(find.byKey(seriesTargetKey));
      final total = tester.getRect(find.byKey(seriesTotalKey));
      // The totals sit strictly below the target — a single stacked column.
      expect(total.top, greaterThan(target.bottom));
    });

    testWidgets('lays the target beside the totals on a wide surface', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1200, 900));

      final target = tester.getRect(find.byKey(seriesTargetKey));
      final total = tester.getRect(find.byKey(seriesTotalKey));
      // The totals sit to the right of the target and overlap it vertically —
      // a side-by-side arrangement, not a stacked column.
      expect(total.left, greaterThan(target.right));
      expect(total.top, lessThan(target.bottom));
    });
  });

  group('accessibility semantics', () {
    testWidgets('labels the target and the series total for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));

      // The target announces what it is and how to use it.
      expect(
        find.bySemanticsLabel('Skyteskive — trykk for å plassere skudd'),
        findsOneWidget,
      );
      // The series total reads its value in words, not loose digits.
      expect(
        find.bySemanticsLabel('Serie-sum: 0 av 100'),
        findsOneWidget,
      );
      // The seal / advance action carries a Norwegian tooltip.
      expect(find.byTooltip('Fullfør serie'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the series-total label updates with the spoken value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));

      // Placing a centre shot (ring 10) updates the spoken total in words.
      await tapTarget(tester);
      expect(
        find.bySemanticsLabel('Serie-sum: 10 av 100'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Serie-sum: 0 av 100'), findsNothing);

      handle.dispose();
    });

    testWidgets('labels the session total on the scorecard', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
      await completeAirRifle(tester);

      expect(find.byKey(sessionCompleteKey), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Økt-sum: \d+ av 100')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('speaks the inner-ten count, singular then plural', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_precision5));

      // One centre shot: ring 10, one inner ten -> singular "indre tier".
      await tapTarget(tester);
      expect(
        find.bySemanticsLabel('Serie-sum: 10 av 50, 1 indre tier'),
        findsOneWidget,
      );

      // A second centre shot pluralises to "indre tiere".
      await tapTarget(tester);
      expect(
        find.bySemanticsLabel('Serie-sum: 20 av 50, 2 indre tiere'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Serie-sum: 10 av 50, 1 indre tier'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('marks the stage header as a header with a composed label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_twoStage));

      final header = find.bySemanticsLabel('A. serie 1/1, stadium 1/2');
      expect(header, findsOneWidget);
      expect(tester.getSemantics(header), isSemantics(isHeader: true));

      handle.dispose();
    });

    testWidgets('labels each shot row, placed and unplaced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_precision5));

      // Before placing: every row reads as not yet placed.
      expect(
        find.bySemanticsLabel('Skudd 1: ikke plassert'),
        findsOneWidget,
      );

      // A centre shot scores ring 10 as an inner ten, with the suffix spoken.
      await tapTarget(tester);
      expect(find.bySemanticsLabel('Skudd 1: 10, indre tier'), findsOneWidget);
      expect(find.bySemanticsLabel('Skudd 2: ikke plassert'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('labels the shots list with the placed count', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));

      expect(
        find.bySemanticsLabel('Skudd: 0 av 10 plassert'),
        findsOneWidget,
      );

      await tapTarget(tester);
      expect(
        find.bySemanticsLabel('Skudd: 1 av 10 plassert'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Skudd: 0 av 10 plassert'), findsNothing);

      handle.dispose();
    });

    testWidgets('labels the session-so-far total on a multi-series program', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ProgramCatalogue.standardPistol25m));

      // 12 series of 5 on the precision face -> 600 max; a centre shot adds 10
      // with one inner ten.
      await tapTarget(tester);
      expect(
        find.bySemanticsLabel('Økt så langt: 10 av 600, 1 indre tier'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('labels a stage row on the scorecard', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_twoStage));

      // Shoot both stages with centre shots, then seal to the scorecard.
      await tapTarget(tester);
      await tapTarget(tester);
      await tester.tap(find.byKey(sealSeriesKey)); // advance to stage B
      await tester.pumpAndSettle();
      await tapTarget(tester);
      await tapTarget(tester);
      await tester.tap(find.byKey(sealSeriesKey)); // finish
      await tester.pumpAndSettle();

      expect(find.byKey(sessionCompleteKey), findsOneWidget);
      // Stage A: two ring-10 inner tens out of two shots -> 20 of 20.
      expect(
        find.bySemanticsLabel('A: 20 av 20, 2 indre tiere'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('scorecard metadata caption', () {
    testWidgets('stamps the date and place when both are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ProgramCatalogue.airRifle10m,
          metadata: SessionMetadata(
            capturedAt: DateTime(2026, 6, 21, 14, 30),
            place: const Place(label: 'Løvenskiold skytebane'),
          ),
        ),
      );
      await completeAirRifle(tester);

      expect(find.byKey(sessionCompleteKey), findsOneWidget);
      final caption = tester.widget<Text>(find.byKey(sessionMetadataKey));
      expect(caption.data, '2026-06-21 14:30 · Løvenskiold skytebane');
    });

    testWidgets('shows the timestamp only when the place is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ProgramCatalogue.airRifle10m,
          metadata: SessionMetadata(
            capturedAt: DateTime(2026, 6, 21, 14, 30),
          ),
        ),
      );
      await completeAirRifle(tester);

      final caption = tester.widget<Text>(find.byKey(sessionMetadataKey));
      expect(caption.data, '2026-06-21 14:30');
      expect(caption.data, isNot(contains('·')));
    });

    testWidgets('renders no caption when there is no metadata', (tester) async {
      await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
      await completeAirRifle(tester);

      expect(find.byKey(sessionCompleteKey), findsOneWidget);
      expect(find.byKey(sessionMetadataKey), findsNothing);
    });

    testWidgets('appends the chosen weapon name to the caption', (
      tester,
    ) async {
      final rifle = Weapon.fromClass(
        const WeaponClass(
          discipline: Discipline.rifle,
          caliberLabel: '4.5 mm',
          label: 'Air 4.5 mm',
        ),
        id: 'r1',
        name: 'My air rifle',
      );
      await tester.pumpWidget(
        _app(
          ProgramCatalogue.airRifle10m,
          metadata: SessionMetadata(
            capturedAt: DateTime(2026, 6, 21, 14, 30),
            place: const Place(label: 'Løvenskiold skytebane'),
          ),
          weapon: rifle,
        ),
      );
      await completeAirRifle(tester);

      final caption = tester.widget<Text>(find.byKey(sessionMetadataKey));
      expect(
        caption.data,
        '2026-06-21 14:30 · Løvenskiold skytebane · My air rifle',
      );
    });
  });
}

Widget _app(
  ProgramDefinition program, {
  SessionMetadata? metadata,
  Weapon? weapon,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: SeriesScreen(
        program: program,
        metadata: metadata,
        weapon: weapon,
      ),
    ),
  );
}
