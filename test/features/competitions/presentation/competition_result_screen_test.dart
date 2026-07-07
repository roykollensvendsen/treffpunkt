// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the scoreboard result view (specs 0026/0140): ring
// payloads render the ring scorecard, felt payloads the felt scorecard,
// anything else an honest message.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_result_screen.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

void main() {
  testWidgets('a felt payload renders the felt scorecard (spec 0140)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final record = FeltSessionRecord(
      id: 'felt-r1',
      capturedAt: DateTime(2026, 7, 5, 12),
      competitionId: 'felt-c1',
      session: const FeltSessionSnapshot(
        group: FeltShooterGroup.two,
        currentHold: 7,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[
            FeltPlacedShot(dx: 38, dy: 97, figureIndex: 0, inner: true),
          ],
        ],
      ),
    );
    final result = CompetitionResult(
      id: record.id,
      competitionId: 'felt-c1',
      program: feltCompetitionProgram(
        norgesfelt2026Course,
        FeltShooterGroup.two,
      ),
      total: 2,
      maxTotal: 47,
      innerTens: 1,
      payload: record.toJson(),
    );

    await tester.pumpWidget(
      MaterialApp(home: CompetitionResultScreen(result: result)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeltScorecard), findsOneWidget);
    expect(find.byKey(unreadableResultKey), findsNothing);
  });

  testWidgets('garbage stays honestly unreadable (spec 0026)', (
    tester,
  ) async {
    const result = CompetitionResult(
      id: 'x',
      competitionId: 'c',
      program: 'ukjent',
      total: 0,
      maxTotal: 0,
      innerTens: 0,
      payload: <String, dynamic>{'hva': 'som helst'},
    );
    await tester.pumpWidget(
      const MaterialApp(home: CompetitionResultScreen(result: result)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(unreadableResultKey), findsOneWidget);
  });
}
