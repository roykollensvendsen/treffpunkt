// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for recording and viewing T96 (spec 0160): the recorder's
// serie header with time and position, inner hits scoring points, the
// scorecard breakdown and the course preview.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

void main() {
  // The T96 sheet is a 150×150 canvas (spec 0160): circle centres at
  // (25,25), (125,25), (75,75), (25,125), (125,125), r ≈ 22.9, inner
  // ring r ≈ 9.4.
  const innerFrac = Offset(25 / 150, 25 / 150);
  const outerFrac = Offset(40 / 150, 25 / 150);

  Future<void> tapRecorder(WidgetTester tester, Offset frac) async {
    final rect = tester.getRect(find.byKey(feltHoldRecorderKey));
    await tester.tapAt(
      rect.topLeft + Offset(frac.dx * rect.width, frac.dy * rect.height),
    );
    await tester.pump();
  }

  Future<void> pumpRecorder(
    WidgetTester tester,
    FeltShooterGroup group,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: FeltRecordScreen(course: t96Course, group: group),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the T96 recorder titles the serie with time and stilling '
      '(spec 0160)', (tester) async {
    await pumpRecorder(tester, FeltShooterGroup.one);

    expect(find.text('Serie 1/16'), findsOneWidget);
    expect(find.text('11 m  ·  150 sek  ·  Stående fri'), findsOneWidget);

    // Serie 2 is the one-handed 150 s serie.
    await tester.tap(find.text('Neste'));
    await tester.pumpAndSettle();
    expect(find.text('Serie 2/16'), findsOneWidget);
    expect(
      find.text('11 m  ·  150 sek  ·  Stående 1 hånd'),
      findsOneWidget,
    );
  });

  testWidgets('Magnum (Gruppe 3) reads two hands on every serie '
      '(spec 0160)', (tester) async {
    await pumpRecorder(tester, FeltShooterGroup.three);

    expect(find.text('11 m  ·  150 sek  ·  Stående 2 hender'), findsOneWidget);
    await tester.tap(find.text('Neste'));
    await tester.pumpAndSettle();
    expect(find.text('11 m  ·  150 sek  ·  Stående 2 hender'), findsOneWidget);
  });

  testWidgets('an inner hit scores a point on T96 (spec 0160)', (
    tester,
  ) async {
    await pumpRecorder(tester, FeltShooterGroup.two);

    // Dead centre of the top-left circle: treff + figur + inner = 3.
    await tapRecorder(tester, innerFrac);
    expect(
      find.text('Treff 1 · Figur 1 · Inner 1  =  3 poeng'),
      findsOneWidget,
    );
    expect(find.text('Totalt så langt: 3 poeng'), findsOneWidget);

    // A second hit on the same circle outside the inner ring: +1 treff.
    await tapRecorder(tester, outerFrac);
    expect(
      find.text('Treff 2 · Figur 1 · Inner 1  =  4 poeng'),
      findsOneWidget,
    );
    expect(find.text('Totalt så langt: 4 poeng'), findsOneWidget);
  });

  testWidgets('the T96 scorecard breaks down serier with inner points '
      '(spec 0160)', (tester) async {
    final session = FeltSessionTally(
      group: FeltShooterGroup.one,
      holds: <FeltHoldTally>[
        for (var i = 0; i < 2; i++)
          const FeltHoldTally(<FeltShot>[
            FeltShot(figureIndex: 0, inner: true),
            FeltShot(figureIndex: 1),
          ], innerScores: true),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeltScorecard(session: session, course: t96Course),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Serie 1'), findsOneWidget);
    expect(find.text('Serie 2'), findsOneWidget);
    // 2 treff + 2 figurer + 1 inner = 5 per serie, 10 in the total card.
    expect(find.text('Treff 2 · Figur 2 · Inner 1'), findsNWidgets(2));
    expect(find.text('5'), findsNWidgets(2));
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('the T96 preview lists 16 serier with times and the Magnum '
      'note (spec 0160)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: FeltCourseScreen(course: t96Course)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('16 serier · maks 272/240/240 poeng'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Magnum (Gruppe 3) skyter alle serier med to '
        'hender',
      ),
      findsOneWidget,
    );
    expect(find.text('Serie 1  ·  11 m  ·  150 sek'), findsOneWidget);

    // The last serie is 25 m, 20 sek, stående fri.
    await tester.scrollUntilVisible(
      find.byKey(feltHoldCardKey(16)),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Serie 16  ·  25 m  ·  20 sek'), findsOneWidget);
  });

  testWidgets('the NorgesFelt preview keeps its 10-sek summary (spec 0160)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: FeltCourseScreen(course: norgesfelt2026Course),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('8 hold · 10 sek skytetid · maks 80/70 poeng'),
      findsOneWidget,
    );
  });
}
