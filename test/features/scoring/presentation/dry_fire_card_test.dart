// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_card.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';

import '../../../support/pump_app.dart';

void main() {
  Future<InMemoryDryFireStore> pumpCard(
    WidgetTester tester, {
    List<DryFireEntry> seed = const <DryFireEntry>[],
  }) async {
    final store = InMemoryDryFireStore();
    if (seed.isNotEmpty) await store.save(seed);
    await pumpApp(
      tester,
      home: const Scaffold(body: DryFireCard()),
      overrides: [dryFireStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('empty state invites the first registration (spec 0161)', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byKey(dryFireCardKey), findsOneWidget);
    expect(find.text('Tørrtrening'), findsOneWidget);
    expect(find.text('Registrer tørravtrekk'), findsOneWidget);
  });

  testWidgets('the sheet offers every weapon type and both disciplines '
      '(spec 0165)', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();

    for (final weapon in DryFireWeapon.values) {
      expect(find.byKey(dryFireWeaponChipKey(weapon)), findsOneWidget);
    }
    // Air pistol has a duel form too, so nothing is hidden.
    expect(find.text('Presisjon'), findsOneWidget);
    expect(find.text('Duell'), findsOneWidget);
  });

  testWidgets('registering shows the grand total on the card (spec 0165)', (
    tester,
  ) async {
    final store = await pumpCard(tester);

    // Open the sheet and register 25 pulls on the defaults (Luftpistol,
    // Presisjon).
    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(dryFireCountFieldKey), '25');
    await tester.tap(find.byKey(dryFireRegisterKey));
    await tester.pumpAndSettle();

    expect(find.text('25 avtrekk'), findsOneWidget);
    final saved = await store.load();
    expect(saved.single.weapon, DryFireWeapon.luftpistol);
    expect(saved.single.discipline, DryFireDiscipline.presisjon);
    expect(saved.single.triggerPulls, 25);
  });

  testWidgets('registering saves the chosen weapon and discipline '
      '(spec 0165)', (tester) async {
    final store = await pumpCard(tester);

    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(dryFireWeaponChipKey(DryFireWeapon.grovpistol)),
    );
    await tester.tap(find.text('Duell'));
    await tester.enterText(find.byKey(dryFireCountFieldKey), '40');
    await tester.tap(find.byKey(dryFireRegisterKey));
    await tester.pumpAndSettle();

    final saved = await store.load();
    expect(saved.single.weapon, DryFireWeapon.grovpistol);
    expect(saved.single.discipline, DryFireDiscipline.duell);
    expect(saved.single.triggerPulls, 40);
  });

  testWidgets('the sheet defaults to the last used weapon (spec 0165)', (
    tester,
  ) async {
    await pumpCard(
      tester,
      seed: [
        DryFireEntry(
          id: 'recent',
          recordedAt: DateTime(2026, 7, 27),
          discipline: DryFireDiscipline.presisjon,
          triggerPulls: 30,
          weapon: DryFireWeapon.finpistol,
        ),
      ],
    );

    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.byKey(dryFireWeaponChipKey(DryFireWeapon.finpistol)),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('an empty count is rejected and saves nothing (spec 0161)', (
    tester,
  ) async {
    final store = await pumpCard(tester);

    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();
    // Register with the field left empty.
    await tester.tap(find.byKey(dryFireRegisterKey));
    await tester.pumpAndSettle();

    expect(find.text('Skriv inn et antall over 0'), findsOneWidget);
    expect(await store.load(), isEmpty);
  });
}
