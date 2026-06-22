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
