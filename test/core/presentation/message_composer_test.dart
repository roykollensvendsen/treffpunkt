// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for MessageComposer, the shared attach/write/send row of the
// competition chat and the forum (specs 0051/0053/0054): it exposes the
// caller's controller, sends from the button and the keyboard action, and
// disables both buttons while a send is in flight.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/message_composer.dart';

const Key _fieldKey = ValueKey<String>('field');
const Key _sendKey = ValueKey<String>('send');
const Key _attachKey = ValueKey<String>('attach');

Widget _host({
  required TextEditingController controller,
  VoidCallback? onSend,
  VoidCallback? onAttach,
  ValueChanged<String>? onChanged,
  bool sending = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MessageComposer(
        controller: controller,
        hint: 'Skriv en melding …',
        sending: sending,
        onSend: onSend ?? () {},
        onAttach: onAttach ?? () {},
        onChanged: onChanged,
        fieldKey: _fieldKey,
        sendKey: _sendKey,
        attachKey: _attachKey,
      ),
    ),
  );
}

void main() {
  testWidgets('writes into the given controller and shows the hint', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));

    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).decoration?.hintText,
      'Skriv en melding …',
    );
    await tester.enterText(find.byKey(_fieldKey), 'hei');
    expect(controller.text, 'hei');
  });

  testWidgets('the send button and the keyboard action both send', (
    tester,
  ) async {
    var sends = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller: controller, onSend: () => sends++),
    );

    await tester.tap(find.byKey(_sendKey));
    expect(sends, 1);

    await tester.enterText(find.byKey(_fieldKey), 'hei');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    expect(sends, 2);
  });

  testWidgets('the attach button attaches', (tester) async {
    var attaches = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller: controller, onAttach: () => attaches++),
    );

    await tester.tap(find.byKey(_attachKey));
    expect(attaches, 1);
  });

  testWidgets('forwards onChanged as the user types', (tester) async {
    final changes = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller: controller, onChanged: changes.add),
    );

    await tester.enterText(find.byKey(_fieldKey), 'a');
    expect(changes, ['a']);
  });

  testWidgets('sending disables the attach and send buttons', (tester) async {
    var calls = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        controller: controller,
        sending: true,
        onSend: () => calls++,
        onAttach: () => calls++,
      ),
    );

    await tester.tap(find.byKey(_sendKey));
    await tester.tap(find.byKey(_attachKey));
    expect(calls, 0);
  });
}
