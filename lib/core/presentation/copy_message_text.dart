// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [text] to the clipboard and confirms with a brief snackbar (spec
/// 0069), so a chat message or forum post can be quoted or pasted elsewhere.
///
/// The messenger is read before the `await` so the confirmation is safe across
/// the async gap even if the caller's element is gone by the time it resolves.
Future<void> copyMessageText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Tekst kopiert'),
      duration: Duration(seconds: 1),
    ),
  );
}
