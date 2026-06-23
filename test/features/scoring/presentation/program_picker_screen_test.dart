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
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
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

    expect(find.text('25 m Finpistol'), findsOneWidget);
    expect(find.text('10 m Air Pistol'), findsOneWidget);
    // Air rifle is the spec-0001 reference / fixture but is not offered.
    expect(find.text('10 m Air Rifle'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('program-25 m Finpistol')),
    );
    await tester.pumpAndSettle();

    // Navigated to the session setup step (date/time + place) for the program.
    expect(find.byKey(sessionConfirmKey), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsWidgets);
  });

  testWidgets('labels each program tile as a button for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    final tile = find.bySemanticsLabel(
      RegExp('^Velg program: 10 m Air Pistol'),
    );
    expect(tile, findsOneWidget);

    // A labelled "button" is useless to a screen reader if it carries no tap
    // action: it can be announced but not activated. Assert both the role and
    // the action are present on the very same node.
    expect(
      tester.getSemantics(tile),
      isSemantics(isButton: true, hasTapAction: true),
    );

    handle.dispose();
  });

  testWidgets('activating a program tile via semantics opens setup', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    // A screen-reader double-tap maps to a semantic tap; it must navigate.
    // `semantics.tap` throws if the node carries no tap action, so this also
    // guards against the "announced but inert" defect.
    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^Velg program: 10 m Air Pistol')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(sessionConfirmKey), findsOneWidget);

    handle.dispose();
  });

  testWidgets('shows no resume card when the store is empty', (tester) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(resumeSessionKey), findsNothing);
  });

  testWidgets('the "My sessions" action opens the history screen (spec 0026)', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(mySessionsButtonKey), findsOneWidget);
    expect(find.byTooltip('Mine økter'), findsOneWidget);

    await tester.tap(find.byKey(mySessionsButtonKey));
    await tester.pumpAndSettle();

    // Navigated to the "Mine økter" screen; an empty store shows its empty
    // state rather than crashing.
    expect(find.byType(MySessionsScreen), findsOneWidget);
    expect(find.byKey(noSessionsKey), findsOneWidget);
  });

  testWidgets(
    'the empty-state "Velg program" button returns to the picker (spec 0026)',
    (tester) async {
      await tester.pumpWidget(app(InMemorySessionStore()));
      await tester.pumpAndSettle();

      // Open the empty "Mine økter" history.
      await tester.tap(find.byKey(mySessionsButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(MySessionsScreen), findsOneWidget);
      expect(find.byKey(pickProgramButtonKey), findsOneWidget);

      // Tapping the call to action pops back to the program picker.
      await tester.tap(find.byKey(pickProgramButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(MySessionsScreen), findsNothing);
      expect(find.byType(ProgramPickerScreen), findsOneWidget);
      expect(find.text('Velg program'), findsWidgets);
    },
  );

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
    // The discard action carries a Norwegian tooltip (its accessible label).
    expect(find.byTooltip('Forkast lagret økt'), findsOneWidget);

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
