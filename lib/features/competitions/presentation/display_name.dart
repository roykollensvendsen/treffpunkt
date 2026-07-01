// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';

/// Key for the display-name text field in the editor (spec 0072).
const Key displayNameFieldKey = ValueKey<String>('displayNameField');

/// Key for the "Lagre" action in the display-name editor (spec 0072).
const Key displayNameSaveKey = ValueKey<String>('displayNameSave');

/// Saves the signed-in user's [name] as their display name (spec 0072) and
/// refreshes [currentProfileProvider] so it shows immediately everywhere.
///
/// Names are joined live onto messages, so a change appears retroactively on
/// existing chat/forum posts too. The avatar (if any) is preserved.
Future<void> saveDisplayName(WidgetRef ref, String name) async {
  final id = ref.read(currentUserIdProvider);
  if (id == null) return;
  final previous = ref.read(currentProfileProvider).value;
  await ref
      .read(competitionRepositoryProvider)
      .upsertOwnProfile(
        Profile(id: id, displayName: name, avatarUrl: previous?.avatarUrl),
      );
  ref.invalidate(currentProfileProvider);
}

/// Ensures the user has a display name before posting (spec 0072).
///
/// Returns `true` when a name is set — already, or just chosen in the prompt —
/// and `false` if the user dismisses the prompt without choosing one, in which
/// case the caller should abort the post. A pseudonym is fine: the name need
/// not be the real one.
Future<bool> ensureDisplayName(BuildContext context, WidgetRef ref) async {
  final profile = await ref.read(currentProfileProvider.future);
  if ((profile?.displayName?.trim() ?? '').isNotEmpty) return true;
  if (!context.mounted) return false;
  final chosen = await showDisplayNameDialog(context, initial: '');
  if (chosen == null || chosen.isEmpty) return false;
  await saveDisplayName(ref, chosen);
  return true;
}

/// Shows the display-name editor, pre-filled with [initial]. Resolves to the
/// trimmed new name, or `null` if cancelled.
Future<String?> showDisplayNameDialog(
  BuildContext context, {
  required String initial,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DisplayNameDialog(initial: initial),
);

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Velg brukernavn'),
    content: TextField(
      key: displayNameFieldKey,
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: const InputDecoration(
        labelText: 'Brukernavn',
        helperText:
            'Kan være et kallenavn — trenger ikke være ditt egentlige '
            'navn.',
        helperMaxLines: 2,
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        key: displayNameSaveKey,
        onPressed: _save,
        child: const Text('Lagre'),
      ),
    ],
  );

  // Empty input is a no-op (a name is required); a real name closes with it.
  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}
