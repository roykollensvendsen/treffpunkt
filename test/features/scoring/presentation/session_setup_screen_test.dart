// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the session setup screen: capture date/time and place
// (from GPS if available, or typed by hand) before shooting (spec 0008).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

import '../fake_location_service.dart';

void main() {
  final clock = DateTime(2026, 6, 21, 14, 30);

  Widget app(FakeLocationService location, {ProgramDefinition? program}) {
    return ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(location)],
      child: MaterialApp(
        home: SessionSetupScreen(
          program: program ?? ProgramCatalogue.airRifle10m,
          now: clock,
        ),
      ),
    );
  }

  testWidgets('shows the program name, the default date and a confirm action', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeLocationService()));

    expect(find.text('10 m Air Rifle'), findsWidgets);
    expect(find.byKey(sessionConfirmKey), findsOneWidget);
    // The default date/time is seeded from the injected clock.
    expect(find.textContaining('2026-06-21'), findsOneWidget);
  });

  // Reads the metadata threaded into the session on the pushed SeriesScreen
  // scope, so the GPS fix carried into the session can be asserted exactly.
  SessionMetadata? pushedMetadata(WidgetTester tester) {
    final context = tester.element(find.byKey(seriesTargetKey));
    return ProviderScope.containerOf(
      context,
    ).read(currentSessionMetadataProvider);
  }

  testWidgets('using my location fills the place from a GPS fix', (
    tester,
  ) async {
    final location = FakeLocationService(
      fix: const DeviceLocation(latitude: 59.9, longitude: 10.7),
    );
    await tester.pumpWidget(app(location));

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    expect(location.callCount, 1);
    final field = tester.widget<TextField>(find.byKey(placeFieldKey));
    expect(field.controller!.text, '59.9000, 10.7000');

    // Confirming carries the exact fix into the recorded session's metadata.
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();
    expect(find.byKey(seriesTargetKey), findsOneWidget);

    final place = pushedMetadata(tester)!.place!;
    expect(place.latitude, 59.9);
    expect(place.longitude, 10.7);
  });

  testWidgets('a GPS fix does not overwrite an already-typed label', (
    tester,
  ) async {
    final location = FakeLocationService(
      fix: const DeviceLocation(latitude: 59.9, longitude: 10.7),
    );
    await tester.pumpWidget(app(location));

    // Type a label first, then ask for the fix.
    await tester.enterText(find.byKey(placeFieldKey), 'Min bane');
    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    // The typed label is preserved; the field is not replaced by coordinates.
    final field = tester.widget<TextField>(find.byKey(placeFieldKey));
    expect(field.controller!.text, 'Min bane');

    // Confirming keeps the label AND carries the fix's coordinates.
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    final place = pushedMetadata(tester)!.place!;
    expect(place.label, 'Min bane');
    expect(place.latitude, 59.9);
    expect(place.longitude, 10.7);
  });

  testWidgets('proceeds with a typed place when GPS returns no fix', (
    tester,
  ) async {
    final location = FakeLocationService(); // no fix
    await tester.pumpWidget(app(location));

    // Asking for location yields nothing; the shooter can still type a place.
    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();
    expect(location.callCount, 1);

    await tester.enterText(find.byKey(placeFieldKey), 'Løvenskiold skytebane');
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    // Navigated on to the shooting screen for the chosen program.
    expect(find.byKey(seriesTargetKey), findsOneWidget);
  });

  testWidgets('confirms straight through with no place at all', (tester) async {
    await tester.pumpWidget(app(FakeLocationService()));

    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(seriesTargetKey), findsOneWidget);
  });
}
