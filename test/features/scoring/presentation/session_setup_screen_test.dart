// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the session setup screen: capture date/time and place
// (from GPS if available, or typed by hand) before shooting (spec 0008).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/geocoder.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

import '../fake_location_service.dart';

void main() {
  final clock = DateTime(2026, 6, 21, 14, 30);

  Widget app(
    FakeLocationService location, {
    ProgramDefinition? program,
    Geocoder? geocoder,
  }) {
    return ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        if (geocoder != null) geocoderProvider.overrideWithValue(geocoder),
      ],
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
    final location = FakeLocationService.fix(latitude: 59.9, longitude: 10.7);
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

  testWidgets('names the place from the coordinates when possible (0076)', (
    tester,
  ) async {
    final location = FakeLocationService.fix(latitude: 59.9, longitude: 10.7);
    await tester.pumpWidget(
      app(location, geocoder: _FakeGeocoder('Løvenskiold skytebane')),
    );

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    // The field shows the resolved name, not the coordinates.
    final field = tester.widget<TextField>(find.byKey(placeFieldKey));
    expect(field.controller!.text, 'Løvenskiold skytebane');

    // The name is the label, and the coordinates still ride along.
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();
    final place = pushedMetadata(tester)!.place!;
    expect(place.label, 'Løvenskiold skytebane');
    expect(place.latitude, 59.9);
    expect(place.longitude, 10.7);
  });

  testWidgets('a GPS fix does not overwrite an already-typed label', (
    tester,
  ) async {
    final location = FakeLocationService.fix(latitude: 59.9, longitude: 10.7);
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

  testWidgets('offers "Åpne innstillinger" when location is permanently denied '
      'and tapping it opens the OS settings', (tester) async {
    final location = FakeLocationService(
      result: const LocationDeniedForever(),
    );
    await tester.pumpWidget(app(location));

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    // The open-settings affordance appears.
    expect(find.byKey(openLocationSettingsKey), findsOneWidget);
    expect(find.text('Åpne innstillinger'), findsOneWidget);

    await tester.tap(find.byKey(openLocationSettingsKey));
    await tester.pump();
    expect(location.openSettingsCount, 1);

    // Let the SnackBar finish dismissing so it no longer overlaps the confirm
    // button, then prove manual entry still works: typing a place and
    // confirming reaches the shooting screen with that label in the metadata.
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(placeFieldKey), 'Skytebanen');
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(seriesTargetKey), findsOneWidget);
    expect(pushedMetadata(tester)!.place!.label, 'Skytebanen');
  });

  testWidgets('does not offer "Åpne innstillinger" for a plain denial', (
    tester,
  ) async {
    final location = FakeLocationService(result: const LocationDenied());
    await tester.pumpWidget(app(location));

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    expect(find.byKey(openLocationSettingsKey), findsNothing);
  });

  testWidgets('does not offer "Åpne innstillinger" when no fix is available', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeLocationService())); // LocationUnavailable

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    expect(find.byKey(openLocationSettingsKey), findsNothing);
  });

  testWidgets('does not offer "Åpne innstillinger" on a successful fix', (
    tester,
  ) async {
    final location = FakeLocationService.fix(latitude: 59.9, longitude: 10.7);
    await tester.pumpWidget(app(location));

    await tester.tap(find.byKey(useMyLocationKey));
    await tester.pumpAndSettle();

    expect(find.byKey(openLocationSettingsKey), findsNothing);
  });

  // Reads the weapon threaded into the pushed SeriesScreen scope, so the gun
  // carried into the session can be asserted exactly.
  Weapon? pushedWeapon(WidgetTester tester) {
    final context = tester.element(find.byKey(seriesTargetKey));
    return ProviderScope.containerOf(context).read(currentWeaponProvider);
  }

  testWidgets('picking a weapon threads it into the recorded session', (
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
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
    );
    addTearDown(container.dispose);
    container.read(weaponsProvider.notifier).add(rifle);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SessionSetupScreen(
            program: ProgramCatalogue.airRifle10m,
            now: clock,
          ),
        ),
      ),
    );

    await tester.tap(find.text('My air rifle'));
    await tester.pump();
    await tester.tap(find.byKey(sessionConfirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(seriesTargetKey), findsOneWidget);
    expect(pushedWeapon(tester), rifle);
  });
}

/// A geocoder that always resolves to a fixed [name] (spec 0076).
class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.name);

  final String name;

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async =>
      name;
}
