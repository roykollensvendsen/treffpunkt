// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// A dry-fire entry appears in «Mine økter» as its own card and can be deleted
// (spec 0163). Auth is left unoverridden, so the log is signed-out and the
// delete stays local — no backend is touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';

void main() {
  testWidgets('a dry-fire entry is a card that can be deleted (spec 0163)', (
    tester,
  ) async {
    final store = InMemoryDryFireStore();
    await store.save([
      DryFireEntry(
        id: 'd1',
        recordedAt: DateTime(2026, 7, 20, 10),
        discipline: DryFireDiscipline.duell,
        triggerPulls: 30,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dryFireStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The card renders with the discipline and the trigger-pull count.
    expect(find.byKey(dryFireSessionCard('d1')), findsOneWidget);
    expect(find.textContaining('Duell'), findsOneWidget);
    expect(find.text('30 avtrekk'), findsOneWidget);

    // Delete it via the overflow menu and the confirm dialog.
    await tester.tap(find.byKey(deleteSessionMenuKey('d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteSessionConfirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(dryFireSessionCard('d1')), findsNothing);
    expect(await store.load(), isEmpty);
  });

  testWidgets('a card shows the weapon, omitted when it has none (spec 0165)', (
    tester,
  ) async {
    final store = InMemoryDryFireStore();
    await store.save([
      DryFireEntry(
        id: 'w',
        recordedAt: DateTime(2026, 7, 21, 10),
        discipline: DryFireDiscipline.presisjon,
        triggerPulls: 20,
        weapon: DryFireWeapon.grovpistol,
      ),
      DryFireEntry(
        id: 'legacy',
        recordedAt: DateTime(2026, 7, 20, 10),
        discipline: DryFireDiscipline.duell,
        triggerPulls: 15,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dryFireStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: MySessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The weapon card names the weapon in its caption.
    expect(
      find.descendant(
        of: find.byKey(dryFireSessionCard('w')),
        matching: find.textContaining('Grovpistol'),
      ),
      findsOneWidget,
    );
    // The legacy card (no weapon) names no weapon.
    expect(
      find.descendant(
        of: find.byKey(dryFireSessionCard('legacy')),
        matching: find.textContaining('Grovpistol'),
      ),
      findsNothing,
    );
  });
}
