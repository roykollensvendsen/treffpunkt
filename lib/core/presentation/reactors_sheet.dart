// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

/// Key for the "who reacted" sheet, used by tests (spec 0059).
const Key reactorsSheetKey = ValueKey<String>('reactorsSheet');

/// Shows a bottom sheet listing the [names] of everyone who reacted with
/// [emoji] — opened by holding a reaction chip in a chat or the forum
/// (spec 0059).
void showReactors(BuildContext context, String emoji, List<String> names) {
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              key: reactorsSheetKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$emoji  ·  ${names.length}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final name in names)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(name),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
