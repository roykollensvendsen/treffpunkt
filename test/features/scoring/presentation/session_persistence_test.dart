// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for offline persistence (spec 0009): a recording saved mid-
// series to an injected fake store is restored on a fresh mount — same shots,
// weapon and metadata — and completing the session clears the store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

final Weapon _rifle = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.rifle,
    caliberLabel: '4.5 mm',
    label: 'Air 4.5 mm',
  ),
  id: 'r1',
  name: 'My air rifle',
);

final SessionMetadata _metadata = SessionMetadata(
  capturedAt: DateTime(2026, 6, 21, 14, 30),
  place: const Place(label: 'Løvenskiold'),
);

void main() {
  Widget app(SessionStore store, {SessionRecording? restored}) {
    return ProviderScope(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        home: SeriesScreen(
          program: ProgramCatalogue.airRifle10m,
          metadata: _metadata,
          weapon: _rifle,
          restored: restored,
        ),
      ),
    );
  }

  Future<void> tapTarget(WidgetTester tester) async {
    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pump();
  }

  testWidgets('placing shots saves the in-progress recording to the store', (
    tester,
  ) async {
    final store = InMemorySessionStore();
    await tester.pumpWidget(app(store));

    await tapTarget(tester);
    await tapTarget(tester);
    await tester.pumpAndSettle();

    final saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.current!.placedCount, 2);
    expect(saved.session.weapon, _rifle);
    expect(saved.session.metadata, _metadata);
  });

  testWidgets('a saved mid-series recording is restored on a fresh mount', (
    tester,
  ) async {
    final store = InMemorySessionStore();

    // First "run": place three shots, then the app stops.
    await tester.pumpWidget(app(store));
    await tapTarget(tester);
    await tapTarget(tester);
    await tapTarget(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 / 10'), findsOneWidget);

    // A fresh mount restored from the store shows the same three shots, with
    // the same running total — the in-progress series came back intact.
    final restored = SessionRecording.fromSnapshot(
      (await store.load())!,
      fallbackId: () => 'fallback',
    );
    await tester.pumpWidget(app(store, restored: restored));
    await tester.pumpAndSettle();

    expect(find.text('3 / 10'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(seriesTotalKey)).data, '30');

    // And the actually-remounted screen threaded the restored weapon and
    // metadata into its provider scope (not just the test-built object): read
    // them straight off the live SeriesScreen's container.
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(seriesTargetKey)),
    );
    expect(container.read(currentWeaponProvider), _rifle);
    expect(container.read(sessionProvider).session.weapon, _rifle);
    expect(container.read(sessionProvider).session.metadata, _metadata);
  });

  testWidgets('completing the session clears the store', (tester) async {
    final store = InMemorySessionStore();
    await tester.pumpWidget(app(store));

    for (var i = 0; i < 10; i++) {
      await tapTarget(tester);
    }
    await tester.pumpAndSettle();
    expect(await store.load(), isNotNull); // saved while in progress

    await tester.tap(
      find.byKey(sealSeriesKey),
    ); // seals the only series -> done
    await tester.pumpAndSettle();

    expect(find.byKey(sessionCompleteKey), findsOneWidget);
    expect(await store.load(), isNull); // cleared on completion
  });
}
