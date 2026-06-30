// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the guided session screen.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_target_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/silhouette_series_target.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

import '../fake_image_source_service.dart';

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

// A tiny silhouette bank: one series of 3 shots, one shot at each of 3 faces
// (spec 0067) — small enough to complete in a widget test.
const ProgramDefinition _silhouette3 = ProgramDefinition(
  name: 'Silhouette-3',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'S',
      geometry: TargetGeometry.pistol25mRapid(),
      shotsPerSeries: 3,
      seriesCount: 1,
      targetsPerSeries: 3,
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

  testWidgets('silhouette bank records on 5 mini-targets, not one (0067)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_silhouette3));

    // One big focused target plus a thumbnail per silhouette (not the normal
    // single target).
    expect(find.byKey(silhouetteActiveTargetKey), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(silhouetteTargetKey(i)), findsOneWidget);
    }
    expect(find.byKey(seriesTargetKey), findsNothing);
    // The single-face camera scan does not apply, so it is hidden.
    expect(find.byKey(scanTargetActionKey), findsNothing);

    // Tapping the big (active) target places one shot at a time, in order, as
    // the active silhouette advances.
    expect(find.text('0 / 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(silhouetteActiveTargetKey));
      await tester.pump();
      expect(find.text('${i + 1} / 3'), findsOneWidget);
    }
    expect(sealButton(tester).onPressed, isNotNull);
  });

  testWidgets('focusing a thumbnail then shooting still advances (0067)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_silhouette3));

    // Tap the active silhouette's thumbnail (pins focus), then shoot it.
    await tester.tap(find.byKey(silhouetteTargetKey(0)));
    await tester.pump();
    await tester.tap(find.byKey(silhouetteActiveTargetKey));
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);

    // The marker must have advanced to silhouette 2 — a further shot lands.
    await tester.tap(find.byKey(silhouetteActiveTargetKey));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('the scorecard reviews a silhouette series as a bank (0067)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_silhouette3));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(silhouetteActiveTargetKey));
      await tester.pump();
    }
    await tester.tap(find.byKey(sealSeriesKey));
    await tester.pumpAndSettle();

    expect(find.byKey(sessionCompleteKey), findsOneWidget);
    // The review of the series is a bank of 3 mini-targets, not one face.
    final review = find.byKey(seriesReviewTargetKey(0, 0));
    expect(review, findsOneWidget);
    expect(
      find.descendant(of: review, matching: find.byType(CustomPaint)),
      findsNWidgets(3),
    );
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

  group('last-shot highlight in the shots list', () {
    // The shot number of the row that carries the last-shot highlight key. Each
    // row holds its number (in the avatar) first, then the ring value, so the
    // number is the first Text — and it is what must move as shots are placed.
    String markedShotNumber(WidgetTester tester) {
      final text = find.descendant(
        of: find.byKey(lastShotRowKey),
        matching: find.byType(Text),
      );
      return tester.widget<Text>(text.first).data!;
    }

    testWidgets('marks the most recently placed row and moves the mark', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_precision5));

      // A zero-shot series highlights no row.
      expect(find.byKey(lastShotRowKey), findsNothing);

      // After one shot, the mark is on shot 1.
      await tapTarget(tester);
      expect(find.byKey(lastShotRowKey), findsOneWidget);
      expect(markedShotNumber(tester), '1');

      // A second shot moves the mark to shot 2 — exactly one row stays marked,
      // and it is the new last row, not the old one.
      await tapTarget(tester);
      expect(find.byKey(lastShotRowKey), findsOneWidget);
      expect(markedShotNumber(tester), '2');
    });
  });

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

    testWidgets('labels each series (skive) row on the scorecard', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_twoStage));

      // Shoot both single-series stages with centre shots to the scorecard.
      await tapTarget(tester);
      await tapTarget(tester);
      await tester.tap(find.byKey(sealSeriesKey)); // advance to stage B
      await tester.pumpAndSettle();
      await tapTarget(tester);
      await tapTarget(tester);
      await tester.tap(find.byKey(sealSeriesKey)); // finish
      await tester.pumpAndSettle();

      // Each stage's single skive reads its own per-series score in words.
      expect(
        find.bySemanticsLabel('Serie 1: 20 av 20, 2 indre tiere'),
        findsNWidgets(2),
      );

      handle.dispose();
    });
  });

  group('per-series results on the scorecard (spec 0023)', () {
    // Every per-series (skive) row carries a key whose string starts with the
    // shared key's value, so the rows can be counted across stages.
    final seriesRowPrefix = (seriesResultRowKey as ValueKey<String>).value;
    final seriesRows = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith(seriesRowPrefix) &&
          key.value != seriesRowPrefix;
    });

    // Shoots a multi-series program to completion, sealing every series with
    // centre shots, so the scorecard shows the full per-skive breakdown.
    Future<void> completeProgram(
      WidgetTester tester,
      ProgramDefinition program,
    ) async {
      await tester.pumpWidget(_app(program));
      for (final stage in program.stages) {
        for (var s = 0; s < stage.seriesCount; s++) {
          for (var shot = 0; shot < stage.shotsPerSeries; shot++) {
            await tapTarget(tester);
          }
          await tester.tap(find.byKey(sealSeriesKey));
          await tester.pumpAndSettle();
        }
      }
    }

    testWidgets('lists one row per series under a multi-series stage', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await completeProgram(tester, ProgramCatalogue.finpistol25m);

      expect(find.byKey(sessionCompleteKey), findsOneWidget);

      // Finpistol precision = 6 series, duel = 6 series -> 12 series rows.
      expect(seriesRows, findsNWidgets(12));
      // The first precision series is findable by its stage/series key and
      // reads as a ring-50 skive with five inner tens (five centre shots).
      expect(find.byKey(seriesResultRow(0, 0)), findsOneWidget);
      expect(
        find.bySemanticsLabel('Serie 1: 50 av 50, 5 indre tiere'),
        findsWidgets,
      );

      handle.dispose();
    });

    testWidgets('shows one series row for a single-series program', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await completeProgram(tester, ProgramCatalogue.airRifle10m);

      expect(find.byKey(sessionCompleteKey), findsOneWidget);
      // Air rifle is one 10-shot series -> exactly one series row.
      expect(seriesRows, findsNWidgets(1));
      expect(find.byKey(seriesResultRow(0, 0)), findsOneWidget);
      // Ten centre shots score 100 of 100 (air rifle records no inner ten).
      expect(
        find.bySemanticsLabel('Serie 1: 100 av 100'),
        findsOneWidget,
      );
      // The series' target — showing where the shots landed — is rendered for
      // review (spec 0058).
      expect(find.byKey(seriesReviewTargetKey(0, 0)), findsOneWidget);

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

  group('the target owns wheel/trackpad gestures (spec 0021)', () {
    // The page's scroll body — the SingleChildScrollView wrapping the whole
    // session layout. (The scorecard has its own; on the recording screen this
    // is the only one.)
    SingleChildScrollView pageScrollView(WidgetTester tester) =>
        tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );

    testWidgets(
      'suspends page scrolling while a mouse pointer is over the target, '
      'and restores it when the pointer leaves',
      (tester) async {
        await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));

        // Before any hover the page scrolls with the platform default physics.
        expect(
          pageScrollView(tester).physics,
          isNot(isA<NeverScrollableScrollPhysics>()),
        );

        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        // Hovering the target hands wheel/trackpad zoom and pan to the target,
        // so the page must stop scrolling.
        await mouse.moveTo(tester.getCenter(find.byKey(seriesTargetKey)));
        await tester.pump();
        expect(
          pageScrollView(tester).physics,
          isA<NeverScrollableScrollPhysics>(),
        );

        // Moving off the target restores normal page scrolling.
        await mouse.moveTo(const Offset(2, 2));
        await tester.pump();
        expect(
          pageScrollView(tester).physics,
          isNot(isA<NeverScrollableScrollPhysics>()),
        );
      },
    );

    testWidgets(
      'suspends page scrolling while a finger is pressed on the target, '
      'so a two-finger pinch is not stolen by the page scroll',
      (tester) async {
        await tester.pumpWidget(_app(ProgramCatalogue.airRifle10m));
        expect(
          pageScrollView(tester).physics,
          isNot(isA<NeverScrollableScrollPhysics>()),
        );

        // A finger down on the target suspends the page scroll, so the pinch's
        // scale gesture wins the arena over the page's vertical drag instead of
        // the page stealing it (the vertical-pinch bug on touch).
        // startGesture defaults to a touch pointer.
        final touch = await tester.startGesture(
          tester.getCenter(find.byKey(seriesTargetKey)),
        );
        await tester.pump();
        expect(
          pageScrollView(tester).physics,
          isA<NeverScrollableScrollPhysics>(),
        );

        // Lifting the finger restores normal page scrolling.
        await touch.up();
        await tester.pump();
        expect(
          pageScrollView(tester).physics,
          isNot(isA<NeverScrollableScrollPhysics>()),
        );
      },
    );
  });

  group('scanning a target places shots into the series (spec 0039)', () {
    testWidgets('the scan action commits the placed shots', (tester) async {
      final source = FakeImageSourceService(
        result: ImagePicked(
          PickedImage(bytes: _onePixelPng),
        ),
      );
      await tester.pumpWidget(
        _app(ProgramCatalogue.airRifle10m, imageSource: source),
      );

      // Open the scan screen, pick a photo, accept the default calibration.
      await tester.tap(find.byKey(scanTargetActionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(scanCameraButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(scanCalibrateConfirmKey));
      await tester.pumpAndSettle();

      // A tap on the overlay centre is a ten; confirm returns it to the series.
      await tester.tapAt(tester.getCenter(find.byKey(scanOverlayKey)));
      await tester.pump();
      await tester.ensureVisible(find.byKey(scanConfirmKey));
      await tester.tap(find.byKey(scanConfirmKey));
      await tester.pumpAndSettle();

      expect(find.text('1 / 10'), findsOneWidget);
      expect(totalText(tester), '10');
    });
  });
}

/// A 1×1 transparent PNG, so the scan screen's `Image.memory` decodes.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Widget _app(
  ProgramDefinition program, {
  SessionMetadata? metadata,
  Weapon? weapon,
  ImageSourceService? imageSource,
}) {
  return ProviderScope(
    overrides: [
      if (imageSource != null)
        imageSourceServiceProvider.overrideWithValue(imageSource),
      // Skip the one-time training-data disclosure (spec 0041) in these tests.
      initialDisclosureShownProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      home: SeriesScreen(
        program: program,
        metadata: metadata,
        weapon: weapon,
      ),
    ),
  );
}
