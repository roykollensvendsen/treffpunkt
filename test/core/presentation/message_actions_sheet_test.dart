// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for showMessageActions, the shared long-press action sheet of
// the competition chat and the forum (specs 0051/0063/0069/0070): it offers
// exactly the allowed actions, and tapping one closes the sheet before
// invoking its callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/message_actions_sheet.dart';

const Key _copyKey = ValueKey<String>('copy');
const Key _editKey = ValueKey<String>('edit');
const Key _deleteKey = ValueKey<String>('delete');

Widget _host({
  bool canCopy = false,
  bool canEdit = false,
  bool canDelete = false,
  VoidCallback? onCopy,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showMessageActions(
            context,
            canCopy: canCopy,
            canEdit: canEdit,
            canDelete: canDelete,
            onCopy: onCopy,
            onEdit: onEdit,
            onDelete: onDelete,
            copyKey: _copyKey,
            editKey: _editKey,
            deleteKey: _deleteKey,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows only the allowed actions', (tester) async {
    await tester.pumpWidget(_host(canCopy: true, onCopy: () {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Kopier tekst'), findsOneWidget);
    expect(find.byKey(_copyKey), findsOneWidget);
    expect(find.text('Rediger'), findsNothing);
    expect(find.text('Slett'), findsNothing);
  });

  testWidgets('offers all three when everything is allowed', (tester) async {
    await tester.pumpWidget(
      _host(
        canCopy: true,
        canEdit: true,
        canDelete: true,
        onCopy: () {},
        onEdit: () {},
        onDelete: () {},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Kopier tekst'), findsOneWidget);
    expect(find.text('Rediger'), findsOneWidget);
    expect(find.text('Slett'), findsOneWidget);
  });

  testWidgets('tapping an action closes the sheet, then invokes it', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      _host(
        canCopy: true,
        canEdit: true,
        onCopy: () {},
        onEdit: () {
          edited = true;
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_editKey));
    await tester.pumpAndSettle();

    expect(edited, isTrue);
    expect(find.text('Rediger'), findsNothing);
  });

  testWidgets('tapping Slett invokes onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      _host(canDelete: true, onDelete: () => deleted = true),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_deleteKey));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('tapping Kopier tekst invokes onCopy', (tester) async {
    var copied = false;
    await tester.pumpWidget(_host(canCopy: true, onCopy: () => copied = true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_copyKey));
    await tester.pumpAndSettle();

    expect(copied, isTrue);
  });
}
