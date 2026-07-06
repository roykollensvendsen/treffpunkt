// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The shared message composer of the competition chat and the forum
/// (specs 0051/0053/0054): an attach-image button, a multiline field that
/// sends from the keyboard action, and a filled send button. While [sending]
/// is true both buttons are disabled. Pass the screen's test keys so its
/// finders keep working.
class MessageComposer extends StatelessWidget {
  /// Creates the composer over the caller's [controller].
  const MessageComposer({
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.onAttach,
    this.sending = false,
    this.onChanged,
    this.fieldKey,
    this.sendKey,
    this.attachKey,
    super.key,
  });

  /// The text being composed — owned by the screen, which reads and clears it.
  final TextEditingController controller;

  /// The field's placeholder («Skriv en melding …», «Skriv et svar …»).
  final String hint;

  /// Called from the send button and the keyboard's send action.
  final VoidCallback onSend;

  /// Called from the attach-image button.
  final VoidCallback onAttach;

  /// Whether a send is in flight — disables the attach and send buttons.
  final bool sending;

  /// Forwarded from the field, e.g. to offer @-mentions (spec 0120).
  final ValueChanged<String>? onChanged;

  /// Names the text field for the screen's test finders.
  final Key? fieldKey;

  /// Names the send button for the screen's test finders.
  final Key? sendKey;

  /// Names the attach button for the screen's test finders.
  final Key? attachKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          IconButton(
            key: attachKey,
            tooltip: 'Legg ved bilde',
            onPressed: sending ? null : onAttach,
            icon: const Icon(Icons.image_outlined),
          ),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: sendKey,
            tooltip: 'Send',
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
