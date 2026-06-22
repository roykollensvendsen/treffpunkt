// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the program picker.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

void main() {
  Widget app(SessionStore store) {
    return ProviderScope(
      overrides: [sessionStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ProgramPickerScreen()),
    );
  }

  testWidgets('lists programs and opens the setup screen on tap', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.text('10 m Air Rifle'), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsOneWidget);
    expect(find.text('10 m Air Pistol'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('program-25 m Finpistol')),
    );
    await tester.pumpAndSettle();

    // Navigated to the session setup step (date/time + place) for the program.
    expect(find.byKey(sessionConfirmKey), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsWidgets);
  });

  testWidgets('shows no resume card when the store is empty', (tester) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(resumeSessionKey), findsNothing);
  });

  testWidgets('resumes a saved session restored to its shots', (tester) async {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final current = session
        .newSeries()!
        .placeShot(const Shot(dxMm: 0, dyMm: 0))
        .placeShot(const Shot(dxMm: 0, dyMm: 0));
    final store = InMemorySessionStore();
    await store.save(SessionSnapshot(session: session, current: current));

    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    // The resume card appears and names the saved program.
    expect(find.byKey(resumeSessionKey), findsOneWidget);
    expect(find.textContaining('10 m Air Rifle'), findsWidgets);

    await tester.tap(find.byKey(resumeSessionKey));
    await tester.pumpAndSettle();

    // Reopened the shooting screen restored to the saved two shots.
    expect(find.byKey(seriesTargetKey), findsOneWidget);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('the resume card appears on a fresh mount after a new save', (
    tester,
  ) async {
    final store = InMemorySessionStore();

    // A fresh picker over an empty store shows no resume card.
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.byKey(resumeSessionKey), findsNothing);

    // A recording is saved (as if mid-session), then the picker is mounted
    // fresh again (a new app launch: tear the tree down first so Riverpod
    // builds a new container): the resume card now appears, from the store.
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final current = session.newSeries()!.placeShot(
      const Shot(dxMm: 0, dyMm: 0),
    );
    await store.save(SessionSnapshot(session: session, current: current));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.byKey(resumeSessionKey), findsOneWidget);
  });

  testWidgets('completing a resumed session removes the card on return', (
    tester,
  ) async {
    // A nearly-finished air-rifle series (9 of 10 shots placed) is saved.
    final session = Session.start(ProgramCatalogue.airRifle10m);
    var current = session.newSeries()!;
    for (var i = 0; i < 9; i++) {
      current = current.placeShot(const Shot(dxMm: 0, dyMm: 0));
    }
    final store = InMemorySessionStore();
    await store.save(SessionSnapshot(session: session, current: current));

    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.byKey(resumeSessionKey), findsOneWidget);

    // Resume, place the last shot, seal the series -> session complete.
    await tester.tap(find.byKey(resumeSessionKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(sealSeriesKey));
    await tester.pumpAndSettle();
    expect(find.byKey(sessionCompleteKey), findsOneWidget);

    // Return to the picker: the store is empty and the card is gone — the
    // finished session never resurfaces as a resume.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(resumeSessionKey), findsNothing);
    expect(await store.load(), isNull);
  });

  testWidgets('discarding the saved session removes the card and clears it', (
    tester,
  ) async {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final current = session.newSeries()!.placeShot(
      const Shot(dxMm: 0, dyMm: 0),
    );
    final store = InMemorySessionStore();
    await store.save(SessionSnapshot(session: session, current: current));

    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.byKey(resumeSessionKey), findsOneWidget);

    await tester.tap(find.byKey(discardSessionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(resumeSessionKey), findsNothing);
    expect(await store.load(), isNull);
  });
}
