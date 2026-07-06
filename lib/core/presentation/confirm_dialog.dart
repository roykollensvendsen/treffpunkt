// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Shows the app's standard destructive-action confirmation dialog
/// (spec 0096) and resolves to `true` only when the confirm button is tapped.
///
/// The dialog is an [AlertDialog] with [title], an optional [message] body,
/// an «Avbryt» [TextButton] and a [FilledButton] labelled [confirmLabel].
/// Cancelling — via the button, the barrier or a back gesture — resolves to
/// `false`, so callers can simply `if (!await showConfirmDialog(...)) return;`.
///
/// [confirmKey] tags the confirm button for tests. [destructiveConfirm]
/// paints the confirm button in the theme's error colour for actions with
/// especially heavy consequences (account deletion).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  Key? confirmKey,
  bool destructiveConfirm = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          key: confirmKey,
          style: destructiveConfirm
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
