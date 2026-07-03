// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/mention_text.dart';

/// Key for the mention picker sheet (spec 0120), for tests.
const Key mentionSheetKey = ValueKey<String>('mentionSheet');

/// Key for [name]'s row in the mention picker (spec 0120), for tests.
Key mentionOptionKey(String name) => ValueKey<String>('mention-$name');

/// Offers the mention picker when the user just typed `@` at the start of a
/// word (spec 0120): call from the composer's `onChanged`. Picking a name
/// replaces the `@` with the `@[Navn] ` marker; dismissing leaves the text
/// as typed. No-op when [names] is empty or the caret is not right after a
/// word-initial `@`.
Future<void> maybeOfferMentions(
  BuildContext context,
  TextEditingController controller,
  List<String> names,
) async {
  if (names.isEmpty) return;
  final text = controller.text;
  final caret = controller.selection.baseOffset;
  if (caret < 1 || caret > text.length || text[caret - 1] != '@') return;
  if (caret >= 2 && !RegExp(r'\s').hasMatch(text[caret - 2])) return;
  final name = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        key: mentionSheetKey,
        shrinkWrap: true,
        children: <Widget>[
          for (final name in names)
            ListTile(
              key: mentionOptionKey(name),
              leading: const Icon(Icons.alternate_email),
              title: Text(name),
              onTap: () => Navigator.of(sheetContext).pop(name),
            ),
        ],
      ),
    ),
  );
  if (name == null) return;
  final marker = '${mentionMarker(name)} ';
  controller.value = TextEditingValue(
    text: text.replaceRange(caret - 1, caret, marker),
    selection: TextSelection.collapsed(offset: caret - 1 + marker.length),
  );
}
