// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the shared destructive-action confirmation dialog (spec 0096):
// an AlertDialog with an «Avbryt» TextButton and a filled confirm button,
// resolving true only when the confirm button is tapped.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/confirm_dialog.dart';

void main() {
  const confirmKey = Key('confirm-dialog-test-confirm');

  bool? result;

  setUp(() => result = null);

  /// Pumps a screen with an «open» button that shows the dialog and stores
  /// what it resolves to in [result], mirroring how the call sites use it.
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    String? message = 'Handlingen kan ikke angres.',
    Key? key = confirmKey,
    bool destructiveConfirm = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Slett økt?',
                  message: message,
                  confirmLabel: 'Slett',
                  confirmKey: key,
                  destructiveConfirm: destructiveConfirm,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title, message and both buttons', (tester) async {
    await pumpAndOpen(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Slett økt?'), findsOneWidget);
    expect(find.text('Handlingen kan ikke angres.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Slett'), findsOneWidget);
    expect(find.byKey(confirmKey), findsOneWidget);
  });

  testWidgets('resolves true when the confirm button is tapped', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    await tester.tap(find.byKey(confirmKey));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('resolves false when «Avbryt» is tapped', (tester) async {
    await pumpAndOpen(tester);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('resolves false when dismissed via the barrier', (tester) async {
    await pumpAndOpen(tester);

    // Tap outside the dialog to dismiss it without choosing.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('omits the content when no message is given', (tester) async {
    await pumpAndOpen(tester, message: null);

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.content, isNull);
  });

  testWidgets('works without a confirm key', (tester) async {
    await pumpAndOpen(tester, key: null);

    await tester.tap(find.widgetWithText(FilledButton, 'Slett'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets(
    'styles the confirm button with the error colour when destructive',
    (tester) async {
      await pumpAndOpen(tester, destructiveConfirm: true);

      final button = tester.widget<FilledButton>(find.byKey(confirmKey));
      final dialogContext = tester.element(find.byKey(confirmKey));
      expect(
        button.style?.backgroundColor?.resolve(const <WidgetState>{}),
        Theme.of(dialogContext).colorScheme.error,
      );
    },
  );

  testWidgets('uses the default style when not destructive', (tester) async {
    await pumpAndOpen(tester);

    final button = tester.widget<FilledButton>(find.byKey(confirmKey));
    expect(button.style, isNull);
  });
}
