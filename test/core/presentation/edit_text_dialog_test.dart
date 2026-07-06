// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for showEditTextDialog, the shared single-field editor of the
// competition chat and the forum (specs 0063/0070): it opens on the current
// text, returns the trimmed new text on Lagre and null on Avbryt. The dialog
// owns its TextEditingController so it outlives the dismiss animation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/edit_text_dialog.dart';

const Key _fieldKey = ValueKey<String>('editField');
const Key _saveKey = ValueKey<String>('editSave');

Widget _host(void Function(String?) onResult, {String initialText = 'hei'}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(
              await showEditTextDialog(
                context,
                title: 'Rediger melding',
                initialText: initialText,
                hint: 'Melding …',
                fieldKey: _fieldKey,
                saveKey: _saveKey,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens on the current text with title and hint', (tester) async {
    await tester.pumpWidget(_host((_) {}, initialText: 'gammel tekst'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rediger melding'), findsOneWidget);
    expect(find.text('gammel tekst'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(_fieldKey));
    expect(field.decoration?.hintText, 'Melding …');
  });

  testWidgets('Lagre returns the trimmed new text', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(_host((r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_fieldKey), '  ny tekst  ');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();

    expect(result, 'ny tekst');
    expect(find.byKey(_fieldKey), findsNothing);
  });

  testWidgets('Avbryt returns null', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(_host((r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
