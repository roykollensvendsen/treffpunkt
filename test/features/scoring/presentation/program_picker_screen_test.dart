// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the program picker: the four-category front page and the
// per-category program pages (spec 0084).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/core/presentation/category_pictograms.dart';
import 'package:treffpunkt/core/presentation/target_icon.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/program_category_screen.dart';
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

  testWidgets('shows the four categories and no individual programs', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    // The four category cards, top to bottom in the sketched order (spec
    // 0084 req 1).
    final cards = <Finder>[
      find.byKey(const ValueKey<String>('category-NSF Luft')),
      find.byKey(const ValueKey<String>('category-NSF Fin/Grov')),
      find.byKey(const ValueKey<String>('category-MIL')),
      find.byKey(const ValueKey<String>('category-Felt')),
    ];
    for (final card in cards) {
      expect(card, findsOneWidget);
    }
    // A 2×2 grid (spec 0097): Luft/Fin-Grov on the first row, MIL/Felt on
    // the second.
    final tops = <double>[for (final card in cards) tester.getTopLeft(card).dy];
    expect(tops[0], tops[1]);
    expect(tops[2], tops[3]);
    expect(tops[0], lessThan(tops[2]));

    // The front page carries no individual program tiles any more.
    expect(
      find.byKey(const ValueKey<String>('program-10 m Luftpistol 60 skudd')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('felt-norgesfelt-2026')),
      findsNothing,
    );
  });

  testWidgets('the app bar carries the logo mark and tiles pictograms (0101)', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    // The wordmark's target beside the title, plus one on each precision
    // category tile (Luft and Fin/Grov).
    expect(find.byType(TargetIcon), findsNWidgets(3));
    // MIL wears the silhouette its programs are shot on, Felt the
    // square-and-circle figure pair of its holds.
    expect(find.byType(SilhouettePictogram), findsOneWidget);
    expect(find.byType(FeltFiguresPictogram), findsOneWidget);
  });

  testWidgets('NSF Luft lists the air programs and opens setup on tap', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('category-NSF Luft')));
    await tester.pumpAndSettle();

    // The category page lists the air programs — and only them.
    expect(
      find.byKey(const ValueKey<String>('program-10 m Luftpistol 60 skudd')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('program-Sprintluft')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('program-25 m Finpistol')),
      findsNothing,
    );
    // Air rifle is the spec-0001 reference / fixture but is not offered.
    expect(find.text('10 m Air Rifle'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('program-10 m Luftpistol 60 skudd')),
    );
    await tester.pumpAndSettle();

    // Navigated to the session setup step (date/time + place) for the program.
    expect(find.byKey(sessionConfirmKey), findsOneWidget);
    expect(find.text('10 m Luftpistol 60 skudd'), findsWidgets);
  });

  testWidgets('NSF Fin/Grov lists the cartridge programs, scrolled into view', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('category-NSF Fin/Grov')),
    );
    await tester.pumpAndSettle();

    // Tap a program further down the list, scrolled into view, to navigate —
    // also proving the list scrolls past the first screenful.
    final program = find.byKey(
      const ValueKey<String>('program-50 m Fripistol'),
    );
    await tester.scrollUntilVisible(program, 80);
    await tester.ensureVisible(program);
    await tester.pumpAndSettle();
    await tester.tap(program);
    await tester.pumpAndSettle();

    expect(find.byKey(sessionConfirmKey), findsOneWidget);
    expect(find.text('50 m Fripistol'), findsWidgets);
  });

  testWidgets('MIL is disabled and marked kommer senere (spec 0097)', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.textContaining('ommer senere'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('category-MIL')));
    await tester.pumpAndSettle();

    // No dead-end page opens — still on the front page.
    expect(find.byType(ProgramPickerScreen), findsOneWidget);
    expect(find.byKey(emptyCategoryKey), findsNothing);
  });

  testWidgets('Felt opens the course preview directly (spec 0097)', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('category-Felt')));
    await tester.pumpAndSettle();

    // One course exists, so the category skips the list (spec 0097 req 4).
    expect(find.byType(FeltCourseScreen), findsOneWidget);
  });

  testWidgets('labels each category card as a button for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    final card = find.bySemanticsLabel(RegExp('^Velg kategori: NSF Luft'));
    expect(card, findsOneWidget);

    // A labelled "button" is useless to a screen reader if it carries no tap
    // action: it can be announced but not activated. Assert both the role and
    // the action are present on the very same node.
    expect(
      tester.getSemantics(card),
      isSemantics(isButton: true, hasTapAction: true),
    );

    handle.dispose();
  });

  testWidgets('activating a category card via semantics opens its page', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    // A screen-reader double-tap maps to a semantic tap; it must navigate.
    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^Velg kategori: NSF Luft')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('program-10 m Luftpistol 60 skudd')),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('labels each program tile as a button for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('category-NSF Luft')));
    await tester.pumpAndSettle();

    final tile = find.bySemanticsLabel(
      RegExp('^Velg program: 10 m Luftpistol 60 skudd'),
    );
    expect(tile, findsOneWidget);

    // Role and tap action on the very same node, as for the category cards.
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

    await tester.tap(find.byKey(const ValueKey<String>('category-NSF Luft')));
    await tester.pumpAndSettle();

    // `semantics.tap` throws if the node carries no tap action, so this also
    // guards against the "announced but inert" defect.
    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^Velg program: 10 m Luftpistol 60 skudd')),
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

  testWidgets('shows the build-version stamp (spec 0028)', (tester) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(buildVersionKey), findsOneWidget);
    expect(find.textContaining('build '), findsOneWidget);
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
    // Discarding confirms first (spec 0096).
    await tester.tap(find.byKey(confirmDestructiveKey));
    await tester.pumpAndSettle();

    expect(find.byKey(resumeSessionKey), findsNothing);
    expect(await store.load(), isNull);
  });

  testWidgets('Skyt igjen names the last exercise and opens setup (0097)', (
    tester,
  ) async {
    // One completed, dated session on the account.
    final repository = InMemorySessionRepository();
    await repository.upload(
      SessionRecord(
        id: 'r1',
        program: '10 m Luftpistol 60 skudd',
        capturedAt: DateTime.utc(2026, 7, 1, 18),
        total: 560,
        maxTotal: 600,
        innerTens: 14,
        payload: const <String, dynamic>{},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ProgramPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The quick-start card names the exercise; one tap reaches its setup.
    expect(find.byKey(shootAgainKey), findsOneWidget);
    expect(find.text('10 m Luftpistol 60 skudd'), findsOneWidget);
    await tester.tap(find.byKey(shootAgainKey));
    await tester.pumpAndSettle();
    expect(find.byKey(sessionConfirmKey), findsOneWidget);
  });

  testWidgets('no history means no Skyt igjen card (spec 0097)', (
    tester,
  ) async {
    await tester.pumpWidget(app(InMemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(shootAgainKey), findsNothing);
  });

  testWidgets('a saved felt round resumes from the front page (0097)', (
    tester,
  ) async {
    final feltStore = InMemoryFeltSessionStore();
    await feltStore.save(
      const FeltSessionSnapshot(
        group: FeltShooterGroup.two,
        currentHold: 1,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[FeltPlacedShot(dx: 1, dy: 1, figureIndex: 0)],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
          <FeltPlacedShot>[],
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
          feltSessionStoreProvider.overrideWithValue(feltStore),
        ],
        child: const MaterialApp(home: ProgramPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(feltResumeSessionKey), findsOneWidget);
    await tester.tap(find.byKey(feltResumeSessionKey));
    await tester.pumpAndSettle();

    // Straight into the recorder, restored (spec 0097 req 3).
    expect(find.byType(FeltRecordScreen), findsOneWidget);
    expect(find.textContaining('Skudd 0/5'), findsOneWidget);
  });
}
