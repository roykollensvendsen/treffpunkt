// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_card.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';

import '../../../support/pump_app.dart';

void main() {
  Future<InMemoryDryFireStore> pumpCard(WidgetTester tester) async {
    final store = InMemoryDryFireStore();
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

  testWidgets('registering a count updates the totals (spec 0161)', (
    tester,
  ) async {
    final store = await pumpCard(tester);

    // Open the sheet and register 25 pulls on the default (Presisjon).
    await tester.tap(find.byKey(dryFireCardKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(dryFireCountFieldKey), '25');
    await tester.tap(find.byKey(dryFireRegisterKey));
    await tester.pumpAndSettle();

    // The card subtitle reflects the new total, and it was persisted.
    expect(find.text('Presisjon 25 · Duell 0'), findsOneWidget);
    final saved = await store.load();
    expect(saved.single.discipline, DryFireDiscipline.presisjon);
    expect(saved.single.triggerPulls, 25);
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
