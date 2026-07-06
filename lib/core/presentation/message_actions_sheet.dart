// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Shows the long-press action sheet for a chat message or a forum post:
/// "Kopier tekst" (spec 0069), "Rediger" your own text (specs 0063/0070) and,
/// where allowed, "Slett" (specs 0051/0063). Each flag adds its row; tapping a
/// row closes the sheet first, then invokes its callback. Pass the screen's
/// test keys so its finders keep working.
Future<void> showMessageActions(
  BuildContext context, {
  bool canCopy = false,
  bool canEdit = false,
  bool canDelete = false,
  VoidCallback? onCopy,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  Key? copyKey,
  Key? editKey,
  Key? deleteKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      void popThen(VoidCallback? action) {
        Navigator.of(sheetContext).pop();
        action?.call();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (canCopy)
              ListTile(
                key: copyKey,
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopier tekst'),
                onTap: () => popThen(onCopy),
              ),
            if (canEdit)
              ListTile(
                key: editKey,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rediger'),
                onTap: () => popThen(onEdit),
              ),
            if (canDelete)
              ListTile(
                key: deleteKey,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Slett'),
                onTap: () => popThen(onDelete),
              ),
          ],
        ),
      );
    },
  );
}
