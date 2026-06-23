// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

/// Key for the theme-mode app-bar action, used by tests (spec 0030).
const Key themeModeButtonKey = ValueKey<String>('themeModeButton');

/// Key for the menu entry that selects [mode], used by tests (spec 0030).
Key themeModeOption(ThemeMode mode) =>
    ValueKey<String>('themeModeOption-${mode.name}');

/// An app-bar action to choose the theme: follow the system/browser theme
/// (the default), or force light or dark (spec 0030).
///
/// The current choice is read from [themeModeProvider] and shown with a check;
/// selecting an option persists it through the notifier so it survives a
/// restart. The icon reflects the active choice (auto / light / dark).
class ThemeModeButton extends ConsumerWidget {
  /// Creates the theme-mode action.
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      key: themeModeButtonKey,
      icon: Icon(_iconFor(mode)),
      tooltip: 'Tema',
      initialValue: mode,
      onSelected: (selected) =>
          ref.read(themeModeProvider.notifier).select(selected),
      itemBuilder: (context) => <PopupMenuEntry<ThemeMode>>[
        _item(ThemeMode.system, Icons.brightness_auto, 'System'),
        _item(ThemeMode.light, Icons.light_mode, 'Lyst'),
        _item(ThemeMode.dark, Icons.dark_mode, 'Mørkt'),
      ],
    );
  }

  PopupMenuItem<ThemeMode> _item(ThemeMode mode, IconData icon, String label) =>
      PopupMenuItem<ThemeMode>(
        key: themeModeOption(mode),
        value: mode,
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );

  static IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.light => Icons.light_mode,
    ThemeMode.dark => Icons.dark_mode,
  };
}
