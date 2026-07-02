// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the «Rekorder» page (spec 0102).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/scoring/data/personal_records_store.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_screen.dart';

void main() {
  final exercise = ProgramCatalogue.all.first.name;

  Widget app({
    Map<String, ExerciseResult>? baselines,
    List<SessionRecord>? syncedRecords,
    PersonalRecordsStore? store,
  }) {
    return ProviderScope(
      overrides: [
        if (baselines != null)
          initialPersonalRecordsProvider.overrideWithValue(baselines),
        if (syncedRecords != null)
          syncedSessionsProvider.overrideWith((ref) async => syncedRecords),
        if (store != null)
          personalRecordsStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: PersonalRecordsScreen()),
    );
  }

  testWidgets('lists the catalogue programs and both felt groups', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(recordRowKey(exercise)), findsOneWidget);
    for (final group in [FeltShooterGroup.one, FeltShooterGroup.two]) {
      final row = find.byKey(recordRowKey(feltRecordKey(group)));
      await tester.scrollUntilVisible(row, 200);
      expect(row, findsOneWidget);
    }
  });

  testWidgets('with nothing recorded a row shows no record yet', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Ingen rekord ennå'), findsWidgets);
  });

  testWidgets('a saved baseline shows as the record', (tester) async {
    await tester.pumpWidget(
      app(baselines: {exercise: (points: 372, inner: 11)}),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(recordRowKey(exercise)),
        matching: find.textContaining('372 poeng', findRichText: true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a better recorded session beats the baseline', (tester) async {
    await tester.pumpWidget(
      app(
        baselines: {exercise: (points: 372, inner: 11)},
        syncedRecords: [
          SessionRecord(
            id: 's1',
            program: exercise,
            total: 380,
            maxTotal: 600,
            innerTens: 4,
            payload: const <String, dynamic>{},
            capturedAt: DateTime(2026, 7, 1, 18),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(recordRowKey(exercise)),
        matching: find.textContaining('380 poeng', findRichText: true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing a row saves the baseline through the store', (
    tester,
  ) async {
    final store = InMemoryPersonalRecordsStore();
    await tester.pumpWidget(app(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(recordRowKey(exercise)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(recordPointsFieldKey), '372');
    await tester.enterText(find.byKey(recordInnerFieldKey), '11');
    await tester.tap(find.byKey(recordSaveKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(recordRowKey(exercise)),
        matching: find.textContaining('372 poeng', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(await store.load(), {exercise: (points: 372, inner: 11)});
  });

  testWidgets('removing a baseline clears the record again', (tester) async {
    final store = InMemoryPersonalRecordsStore();
    await tester.pumpWidget(
      app(baselines: {exercise: (points: 372, inner: 11)}, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(recordRowKey(exercise)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(recordRemoveKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(recordRowKey(exercise)),
        matching: find.text('Ingen rekord ennå'),
      ),
      findsOneWidget,
    );
    expect(await store.load(), isEmpty);
  });
}
