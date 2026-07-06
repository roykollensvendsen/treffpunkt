// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Opens the shared single-field editor for a chat message or a forum reply
/// (specs 0063/0070): the field starts on [initialText]; "Lagre" resolves to
/// the trimmed new text and "Avbryt" to null. Pass the screen's test keys for
/// the field and the save action so its finders keep working.
Future<String?> showEditTextDialog(
  BuildContext context, {
  required String title,
  required String initialText,
  required String hint,
  Key? fieldKey,
  Key? saveKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditTextDialog(
      title: title,
      initialText: initialText,
      hint: hint,
      fieldKey: fieldKey,
      saveKey: saveKey,
    ),
  );
}

/// Owns its [TextEditingController] so it outlives the dialog's dismiss
/// animation (disposing it from the opener races the fade-out).
class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.title,
    required this.initialText,
    required this.hint,
    required this.fieldKey,
    required this.saveKey,
  });

  final String title;
  final String initialText;
  final String hint;
  final Key? fieldKey;
  final Key? saveKey;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: double.maxFinite,
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        decoration: InputDecoration(hintText: widget.hint),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        key: widget.saveKey,
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: const Text('Lagre'),
      ),
    ],
  );
}
