// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the per-exercise progress charts (spec 0090).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/statistics_screen.dart';

SessionRecord _ring(
  String id,
  String program, {
  required int total,
  required int inner,
  DateTime? capturedAt,
}) => SessionRecord(
  id: id,
  program: program,
  capturedAt: capturedAt,
  total: total,
  maxTotal: 600,
  innerTens: inner,
  payload: <String, dynamic>{'id': id},
);

FeltSessionRecord _felt(String id, {required DateTime capturedAt}) =>
    FeltSessionRecord(
      id: id,
      capturedAt: capturedAt,
      session: const FeltSessionSnapshot(
        group: FeltShooterGroup.one,
        currentHold: 0,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[
            FeltPlacedShot(dx: 1, dy: 1, figureIndex: 0, inner: true),
          ],
        ],
      ),
    );

Future<Widget> _app({
  List<SessionRecord> synced = const <SessionRecord>[],
  List<FeltSessionRecord> feltRounds = const <FeltSessionRecord>[],
  Widget home = const StatisticsScreen(),
}) async {
  final repository = InMemorySessionRepository();
  for (final record in synced) {
    await repository.upload(record);
  }
  final feltHistory = InMemoryFeltHistoryStore();
  await feltHistory.save(feltRounds);
  return ProviderScope(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repository),
      pendingUploadsStoreProvider.overrideWithValue(
        InMemoryPendingUploadsStore(),
      ),
      feltHistoryStoreProvider.overrideWithValue(feltHistory),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  final luft = <SessionRecord>[
    _ring(
      'r1',
      '10 m Luftpistol 60 skudd',
      capturedAt: DateTime.utc(2026, 6, 20),
      total: 560,
      inner: 14,
    ),
    _ring(
      'r2',
      '10 m Luftpistol 60 skudd',
      capturedAt: DateTime.utc(2026, 7, 2),
      total: 570,
      inner: 17,
    ),
  ];

  testWidgets('plots the exercise curves with a legend (spec 0090)', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(synced: luft));
    await tester.pumpAndSettle();

    // The exercise dropdown offers the one exercise with data, selected.
    expect(find.byKey(exerciseDropdownKey), findsOneWidget);
    expect(find.text('10 m Luftpistol 60 skudd'), findsWidgets);

    // The chart and its legend: both series named, colour is not the only
    // carrier of identity.
    expect(find.byKey(progressChartKey), findsOneWidget);
    expect(find.text('Poengsum'), findsOneWidget);
    expect(find.text('Innertreff'), findsOneWidget);

    // The text summary for screen readers (spec 0090 req 7).
    expect(
      find.bySemanticsLabel(RegExp('^Statistikk for 10 m Luftpistol')),
      findsOneWidget,
    );
  });

  testWidgets('switching exercise shows the felt curves too (spec 0090)', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _app(
        synced: luft,
        feltRounds: <FeltSessionRecord>[
          _felt('f1', capturedAt: DateTime.utc(2026, 7)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(exerciseDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NorgesFelt-løype 2026').last);
    await tester.pumpAndSettle();

    expect(find.byKey(progressChartKey), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Statistikk for NorgesFelt')),
      findsOneWidget,
    );
  });

  testWidgets('tapping the chart inspects the nearest session (0090)', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(synced: luft));
    await tester.pumpAndSettle();

    // A tap on the right half lands nearest the newest (second) session.
    final rect = tester.getRect(find.byKey(progressChartKey));
    await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Økt 2: 570 poeng · 17', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('undated-only sessions leave the empty state (spec 0090)', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _app(
        synced: <SessionRecord>[
          _ring('r9', '25 m Finpistol', total: 500, inner: 5),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(noStatisticsKey), findsOneWidget);
    expect(find.byKey(progressChartKey), findsNothing);
  });
}
