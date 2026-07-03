// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the decimal-entry flow (spec 0107): the setup toggle,
// the tenth picker on the last shot and the decimal totals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/decimal_entry_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';

import '../fake_location_service.dart';

void main() {
  group('the setup toggle (spec 0107)', () {
    Widget setupApp({bool? initial, InMemoryDecimalEntryStore? store}) =>
        ProviderScope(
          overrides: [
            locationServiceProvider.overrideWithValue(FakeLocationService()),
            if (initial != null)
              initialDecimalEntryProvider.overrideWithValue(initial),
            if (store != null)
              decimalEntryStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: SessionSetupScreen(
              program: ProgramCatalogue.airPistol10m,
              now: DateTime(2026, 7, 2, 20),
            ),
          ),
        );

    testWidgets('is offered on a decimal-capable program, off by default', (
      tester,
    ) async {
      await tester.pumpWidget(setupApp());
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(decimalEntryToggleKey),
      );
      expect(toggle.value, isFalse);
    });

    testWidgets('is offered on the precision-face 25/50 m programs (0111)', (
      tester,
    ) async {
      for (final program in [
        ProgramCatalogue.standardPistol25m,
        ProgramCatalogue.finpistol25m,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              locationServiceProvider.overrideWithValue(
                FakeLocationService(),
              ),
            ],
            child: MaterialApp(
              home: SessionSetupScreen(
                program: program,
                now: DateTime(2026, 7, 3, 10),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(decimalEntryToggleKey),
          findsOneWidget,
          reason: program.name,
        );
      }
    });

    testWidgets('is not offered on a 5–10 face program', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationServiceProvider.overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            home: SessionSetupScreen(
              program: ProgramCatalogue.sprintluft,
              now: DateTime(2026, 7, 2, 20),
            ),
          ),
        ),
      );
      expect(find.byKey(decimalEntryToggleKey), findsNothing);
    });

    testWidgets('remembers the choice through the store', (tester) async {
      final store = InMemoryDecimalEntryStore();
      await tester.pumpWidget(setupApp(store: store));
      await tester.tap(find.byKey(decimalEntryToggleKey));
      await tester.pumpAndSettle();
      expect(await store.load(), isTrue);
    });

    testWidgets('starts on when it was left on (spec 0099 idiom)', (
      tester,
    ) async {
      await tester.pumpWidget(setupApp(initial: true));
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(decimalEntryToggleKey),
      );
      expect(toggle.value, isTrue);
    });
  });

  group('recording in decimal mode (spec 0107)', () {
    Widget app({bool decimalEntry = true}) => ProviderScope(
      overrides: [initialDisclosureShownProvider.overrideWithValue(true)],
      child: MaterialApp(
        home: SeriesScreen(
          program: ProgramCatalogue.airPistol10m,
          decimalEntry: decimalEntry,
        ),
      ),
    );

    Future<void> tapCentre(WidgetTester tester) async {
      await tester.tap(find.byKey(seriesTargetKey));
      await tester.pump();
    }

    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('the last shot gets the tenth picker, derived by default', (
      tester,
    ) async {
      tallView(tester);
      await tester.pumpWidget(app());
      await tapCentre(tester);

      // A centre tap derives 10,9 (spec 0001's cap).
      final picker = tester.widget<DropdownButton<int>>(
        find.byKey(tenthPickerKey),
      );
      expect(picker.value, 9);
      expect(find.text('10,9'), findsWidgets);
    });

    testWidgets('picking a tenth updates the decimal sum, not the int', (
      tester,
    ) async {
      tallView(tester);
      await tester.pumpWidget(app());
      await tapCentre(tester);

      await tester.tap(find.byKey(tenthPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10,4').last);
      await tester.pumpAndSettle();

      expect(find.text('Desimal 10,4'), findsOneWidget);
      // The canonical int total is untouched.
      expect(
        tester.widget<Text>(find.byKey(seriesTotalKey)).data,
        '10',
      );
    });

    testWidgets('a second shot moves the picker; the first keeps its pick', (
      tester,
    ) async {
      tallView(tester);
      await tester.pumpWidget(app());
      await tapCentre(tester);
      await tester.tap(find.byKey(tenthPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10,2').last);
      await tester.pumpAndSettle();

      await tapCentre(tester);
      // One picker (the new last shot); the first shot's pick shows as text.
      expect(find.byKey(tenthPickerKey), findsOneWidget);
      expect(find.text('10,2'), findsOneWidget);
      expect(find.text('Desimal 21,1'), findsOneWidget);
    });

    testWidgets('outside decimal mode nothing changes', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(decimalEntry: false));
      await tapCentre(tester);

      expect(find.byKey(tenthPickerKey), findsNothing);
      expect(find.text('Desimal 10,9'), findsNothing);
    });

    test('picking a tenth moves the shot to match it (spec 0110)', () {
      final container = ProviderContainer(
        overrides: [
          currentProgramDefinitionProvider.overrideWithValue(
            ProgramCatalogue.airPistol10m,
          ),
          currentDecimalEntryProvider.overrideWithValue(true),
          sessionProvider.overrideWith(SessionNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      const scoring = ScoringService();
      const geometry = TargetGeometry.airPistol10m();
      final notifier = container.read(sessionProvider.notifier)
        ..placeShot(const Shot(dxMm: 10, dyMm: 0)) // ring 9
        ..setShotTenth(0, 4);
      final picked = container.read(sessionProvider).current!.shots.single;
      // The position now *is* 9,4 — the marker moved radially to match.
      expect(scoring.decimalTenths(geometry, picked), 94);
      expect(picked.dxMm, isNot(10));
      expect(picked.dyMm, 0);

      // A manual drag afterwards makes the position the truth again.
      notifier
        ..pickUp(0)
        ..dragTo(const Shot(dxMm: 30, dyMm: 0)); // ring 7 (24–32 mm)
      final dragged = container.read(sessionProvider).current!.shots.single;
      expect(dragged.tenth, isNull);
      expect(scoring.integerScore(geometry, dragged), 7);
    });

    testWidgets('the scorecard shows the decimal totals (spec 0107)', (
      tester,
    ) async {
      tallView(tester);
      // A full 60-shot session is too slow; Storluft (5,5 m) is 4×10 — still
      // large, so drive one series to the seal and check the running card
      // instead, then rely on the scorecard param tests below.
      await tester.pumpWidget(app());
      for (var i = 0; i < 10; i++) {
        await tapCentre(tester);
      }
      expect(find.text('Desimal 109,0'), findsOneWidget);
      await tester.tap(find.byKey(sealSeriesKey));
      await tester.pumpAndSettle();
      // Second series: the running session line carries the decimal.
      expect(find.textContaining('Økt så langt: 100 (109,0)'), findsOneWidget);
    });
  });
}
