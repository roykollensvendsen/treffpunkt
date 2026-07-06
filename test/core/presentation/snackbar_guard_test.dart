// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the shared snackbar failure guard: it runs an async task, shows a
// snackbar with the given message when the task throws, and tells the caller
// whether the task succeeded. The messenger is captured before the await so
// the notice appears even if the triggering widget is gone by then.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/snackbar_guard.dart';

/// A stand-in for the app's sync exceptions.
class _SyncFailure implements Exception {}

/// An unrelated error the typed guard must not swallow.
class _OtherFailure implements Exception {}

void main() {
  /// Pumps a screen with a «run» button that invokes the guard on [task] and
  /// stores whether it reported success in the returned holder.
  Future<List<bool>> pumpAndRun<E extends Object>(
    WidgetTester tester,
    Future<void> Function() task,
  ) async {
    final outcomes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcomes.add(
                  await guardWithSnackBar<E>(
                    context,
                    task: task,
                    failureMessage: 'Kunne ikke slette økten.',
                  ),
                );
              },
              child: const Text('run'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    return outcomes;
  }

  testWidgets('returns true and shows no snackbar when the task succeeds', (
    tester,
  ) async {
    var ran = false;
    final outcomes = await pumpAndRun<Object>(tester, () async {
      ran = true;
    });

    expect(ran, isTrue);
    expect(outcomes, [true]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('returns false and shows the message when the task throws', (
    tester,
  ) async {
    final outcomes = await pumpAndRun<Object>(
      tester,
      () async => throw _SyncFailure(),
    );

    expect(outcomes, [false]);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Kunne ikke slette økten.'), findsOneWidget);
  });

  testWidgets('catches any object by default', (tester) async {
    final outcomes = await pumpAndRun<Object>(
      tester,
      () async => throw StateError('boom'),
    );

    expect(outcomes, [false]);
    expect(find.text('Kunne ikke slette økten.'), findsOneWidget);
  });

  testWidgets('a typed guard catches only that failure type', (tester) async {
    final outcomes = await pumpAndRun<_SyncFailure>(
      tester,
      () async => throw _SyncFailure(),
    );

    expect(outcomes, [false]);
    expect(find.text('Kunne ikke slette økten.'), findsOneWidget);
  });

  testWidgets('a typed guard rethrows other failure types', (tester) async {
    Object? escaped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                try {
                  await guardWithSnackBar<_SyncFailure>(
                    context,
                    task: () async => throw _OtherFailure(),
                    failureMessage: 'Kunne ikke slette økten.',
                  );
                } on Object catch (error) {
                  escaped = error;
                }
              },
              child: const Text('run'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    // The error escapes the guard untouched: no snackbar shown.
    expect(escaped, isA<_OtherFailure>());
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows the snackbar even if the widget is gone after the await', (
    tester,
  ) async {
    // The task removes the triggering subtree before failing, so only a
    // messenger captured before the await can still show the notice.
    final showButton = ValueNotifier<bool>(true);
    addTearDown(showButton.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: showButton,
            builder: (context, visible, _) => visible
                ? TextButton(
                    onPressed: () => guardWithSnackBar<Object>(
                      context,
                      task: () async {
                        showButton.value = false;
                        await Future<void>.delayed(Duration.zero);
                        throw _SyncFailure();
                      },
                      failureMessage: 'Kunne ikke slette økten.',
                    ),
                    child: const Text('run'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(find.text('run'), findsNothing);
    expect(find.text('Kunne ikke slette økten.'), findsOneWidget);
  });
}
