// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for recording a NorgesFelt session (spec 0080).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/core/presentation/personal_best_banner.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';

void main() {
  // Hold 1's hare inner-zone centre as a fraction of the hold (151×145 px).
  const hareFrac = Offset(38.6 / 151, 97.9 / 145);

  Future<void> tapRecorder(WidgetTester tester, Offset frac) async {
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(frac.dx * rect.width, frac.dy * rect.height),
    );
    await tester.pump();
  }

  testWidgets('a competition round opens locked to its group (spec 0140)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(
            competitionId: 'felt-c1',
            group: FeltShooterGroup.two,
          ),
        ),
      ),
    );

    // Straight to hold 1 with the locked group — no group UI exists
    // anywhere in the recorder (spec 0147).
    expect(find.text('Hold 1/8'), findsOneWidget);
    expect(find.textContaining('Skudd 0/5'), findsOneWidget);
  });

  testWidgets('an Asker+ round records 10 holds and stores its course '
      '(spec 0145)', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = InMemoryFeltSessionStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltSessionStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: FeltRecordScreen(
            course: askerPlusCourse,
            group: FeltShooterGroup.one,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hold 1/10'), findsOneWidget);

    // A placed shot persists a snapshot that carries the course id.
    await tapRecorder(tester, hareFrac);
    final saved = await store.load();
    expect(saved?.courseId, 'norgesfelt-asker-plus');
    expect(saved?.holds, hasLength(10));

    // Resuming that snapshot reopens the Asker+ course, not 2026.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feltSessionStoreProvider.overrideWithValue(store)],
        child: MaterialApp(home: FeltRecordScreen(restored: saved)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hold 1/10'), findsOneWidget);
  });

  testWidgets('place a shot, score updates (spec 0080)', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.one),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A hit in the hare's inner zone scores treff + figur = 2; the inner hit
    // is shown as the ringed-X tiebreak count, not as a point (spec 0085).
    await tapRecorder(tester, hareFrac);
    expect(
      find.textContaining(
        'Treff 1 · Figur 1  =  2 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Totalt så langt: 2 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // The inner count is drawn with the same ringed X as the ring programs'
    // inner tens (spec 0023) — one on the hold line, one on the total.
    expect(find.byType(InnerTenX), findsNWidgets(2));
  });

  testWidgets('a hold-2 stripe scores as one figure, middle inner (0086)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.one),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neste'));
    await tester.pumpAndSettle();

    // Hold 2 (247×151): the top stripe's left square centre (21, 20.5) and
    // middle square centre (57.5, 20.5). One figure, the middle is inner —
    // treff 2 + figur 1 = 3 points and a ringed-X count of 1 (specs
    // 0085/0086).
    await tapRecorder(tester, const Offset(21 / 247, 20.5 / 151));
    await tapRecorder(tester, const Offset(57.5 / 247, 20.5 / 151));
    expect(
      find.textContaining(
        'Treff 2 · Figur 1  =  3 poeng · 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('placing is capped at the group shot count (spec 0080)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.one),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 9; i++) {
      await tapRecorder(tester, hareFrac);
    }
    // Group 1 caps at 6 shots per hold.
    expect(find.textContaining('Skudd 6/6'), findsOneWidget);
  });

  testWidgets('finishing shows the scorecard with a total (spec 0080)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(group: FeltShooterGroup.two),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapRecorder(tester, hareFrac);
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Neste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Fullfør'));
    await tester.pumpAndSettle();
    // The scorecard now carries all 8 hold pictures (spec 0105) — a taller
    // viewport so the lazy list builds every row down to the total card.
    tester.view.physicalSize = const Size(600, 6000);
    await tester.pumpAndSettle();

    expect(find.byKey(feltScorecardKey), findsOneWidget);
    // The total renders in the filled result card, like the ring scorecard
    // (spec 0089): the group label, the big points number and the ringed-X
    // inner count (one inner hit on one figure → 2 points · 1 Ⓧ).
    expect(find.textContaining('TOTALT (GRUPPE 2)'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.textContaining('Poeng · 1', findRichText: true),
      findsOneWidget,
    );
    // The placed shots are drawn on the hold pictures (spec 0105): one
    // picture per hold, the hare hit marked on hold 1.
    expect(find.byType(FeltHoldShotsView), findsNWidgets(8));
    expect(find.byType(FeltShotMarker), findsOneWidget);
  });

  group('«Ny pers!» on the finished round (spec 0101)', () {
    // A prior round with [hits] shots on hold 1's first figure:
    // 0 hits → 0 points, 2 hits → treff 2 + figur 1 = 3 points.
    FeltSessionRecord prior({
      required String id,
      required FeltShooterGroup group,
      required int hits,
    }) => FeltSessionRecord(
      id: id,
      capturedAt: DateTime(2026, 6, 1, 12),
      session: FeltSessionSnapshot(
        group: group,
        currentHold: 7,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[
            for (var i = 0; i < hits; i++)
              FeltPlacedShot(dx: 10.0 + i, dy: 10, figureIndex: 0),
          ],
          for (var h = 1; h < 8; h++) const <FeltPlacedShot>[],
        ],
      ),
    );

    // Finishes a gruppe-2 round with one hare inner hit (2 points · 1 Ⓧ).
    Future<void> finishRound(
      WidgetTester tester,
      List<FeltSessionRecord> history, {
      Map<String, ExerciseResult>? baselines,
    }) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feltHistoryProvider.overrideWith((ref) async => history),
            feltSyncedSessionsProvider.overrideWith(
              (ref) async => const <FeltSessionRecord>[],
            ),
            if (baselines != null)
              initialPersonalRecordsProvider.overrideWithValue(baselines),
          ],
          child: const MaterialApp(
            home: FeltRecordScreen(group: FeltShooterGroup.two),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapRecorder(tester, hareFrac);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('Neste'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Fullfør'));
      await tester.pumpAndSettle();
      expect(find.byKey(feltScorecardKey), findsOneWidget);
    }

    testWidgets('beating the group history shows the banner', (tester) async {
      await finishRound(tester, [
        prior(id: 'p1', group: FeltShooterGroup.two, hits: 0),
      ]);
      expect(find.byKey(personalBestKey), findsOneWidget);
      expect(find.text('Ny pers!'), findsOneWidget);
    });

    testWidgets('a higher prior round hides the banner', (tester) async {
      await finishRound(tester, [
        prior(id: 'p1', group: FeltShooterGroup.two, hits: 2),
      ]);
      expect(find.byKey(personalBestKey), findsNothing);
    });

    testWidgets('rounds of the other group do not count', (tester) async {
      await finishRound(tester, [
        prior(id: 'p1', group: FeltShooterGroup.one, hits: 2),
        prior(id: 'p2', group: FeltShooterGroup.two, hits: 0),
      ]);
      expect(find.byKey(personalBestKey), findsOneWidget);
    });

    testWidgets('a same-group baseline above the round hides it (0102)', (
      tester,
    ) async {
      await finishRound(
        tester,
        const [],
        baselines: {
          feltRecordKey(norgesfelt2026Course, FeltShooterGroup.two): (
            points: 60,
            inner: 0,
          ),
        },
      );
      expect(find.byKey(personalBestKey), findsNothing);
    });

    testWidgets("the other group's baseline is ignored (0102)", (
      tester,
    ) async {
      await finishRound(
        tester,
        const [],
        baselines: {
          feltRecordKey(norgesfelt2026Course, FeltShooterGroup.one): (
            points: 60,
            inner: 0,
          ),
          feltRecordKey(norgesfelt2026Course, FeltShooterGroup.two): (
            points: 0,
            inner: 0,
          ),
        },
      );
      expect(find.byKey(personalBestKey), findsOneWidget);
    });
  });
}
