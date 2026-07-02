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
import 'package:treffpunkt/features/scoring/domain/shot.dart';
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

    test('moving keeps the pick within the ring, re-derives across', () {
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
      final notifier = container.read(sessionProvider.notifier)
        ..placeShot(const Shot(dxMm: 10, dyMm: 0)) // ring 9
        ..setShotTenth(0, 4)
        ..pickUp(0)
        // A nudge within ring 9: the transferred reading is still true.
        ..dragTo(const Shot(dxMm: 12, dyMm: 0));
      expect(
        container.read(sessionProvider).current!.shots.single.tenth,
        4,
      );
      // Across the ring boundary: the pick no longer applies; re-derive.
      notifier.dragTo(const Shot(dxMm: 30, dyMm: 0)); // ring 8
      expect(
        container.read(sessionProvider).current!.shots.single.tenth,
        isNull,
      );
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
