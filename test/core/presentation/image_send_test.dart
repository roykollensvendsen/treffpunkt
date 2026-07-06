// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the shared image send pipeline of the competition chat and
// the forum (specs 0062/0075): only real JPG/PNG/GIF bytes reach the sender
// (judged by content, not name), an unsupported file is refused with the
// shared message, and a failing sender is reported with the caller's message.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/image_format.dart';
import 'package:treffpunkt/core/presentation/image_send.dart';

final Uint8List _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]);
final Uint8List _notAnImage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

Widget _host(Future<void> Function(BuildContext) onPressed) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onPressed(context),
          child: const Text('go'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sends supported bytes with their detected format', (
    tester,
  ) async {
    final sent = <(Uint8List, ImageFormat)>[];
    await tester.pumpWidget(
      _host(
        (context) => sendImageBytes(
          context,
          bytes: _png,
          send: (bytes, format) async => sent.add((bytes, format)),
          failureMessage: 'Kunne ikke laste opp bildet.',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.$1, _png);
    expect(sent.single.$2, ImageFormat.png);
  });

  testWidgets('refuses an unsupported file without calling the sender', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      _host(
        (context) => sendImageBytes(
          context,
          bytes: _notAnImage,
          send: (_, _) async => sends++,
          failureMessage: 'Kunne ikke laste opp bildet.',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(sends, 0);
    expect(find.text(unsupportedImageMessage), findsOneWidget);
  });

  testWidgets('a failing sender is reported with the given message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (context) => sendImageBytes(
          context,
          bytes: _png,
          send: (_, _) async => throw Exception('boom'),
          failureMessage: 'Kunne ikke laste opp bildet.',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Kunne ikke laste opp bildet.'), findsOneWidget);
  });

  testWidgets('pickAndSendImage sends what the picker returns', (
    tester,
  ) async {
    final sent = <ImageFormat>[];
    await tester.pumpWidget(
      _host(
        (context) => pickAndSendImage(
          context,
          pickBytes: () async => _png,
          send: (_, format) async => sent.add(format),
          failureMessage: 'Kunne ikke laste opp bildet.',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(sent, [ImageFormat.png]);
  });

  testWidgets('pickAndSendImage does nothing when picking is cancelled', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      _host(
        (context) => pickAndSendImage(
          context,
          pickBytes: () async => null,
          send: (_, _) async => sends++,
          failureMessage: 'Kunne ikke laste opp bildet.',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(sends, 0);
    expect(find.byType(SnackBar), findsNothing);
  });
}
