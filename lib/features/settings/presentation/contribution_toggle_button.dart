// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';

/// Key for the contribution app-bar action, used by tests (spec 0041).
const Key contributionToggleKey = ValueKey<String>('contributionToggle');

/// Key for the menu entry that sets contribution to [enabled], used by tests.
Key contributionToggleOption({required bool enabled}) =>
    ValueKey<String>('contributionToggleOption-${enabled ? 'on' : 'off'}');

/// An app-bar action to turn training-data contribution on or off (spec 0041).
///
/// Reflects [contributionConsentProvider] and flips it through the notifier.
/// Contribution is opt-out (on by default); turning it off stops all future
/// uploads. Mirrors `ThemeModeButton`.
class ContributionToggleButton extends ConsumerWidget {
  /// Creates the contribution action.
  const ContributionToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      contributionConsentProvider.select((c) => c.enabled),
    );
    return PopupMenuButton<bool>(
      key: contributionToggleKey,
      icon: Icon(enabled ? Icons.cloud_upload : Icons.cloud_off),
      tooltip: 'Bidra med treningsbilder',
      initialValue: enabled,
      onSelected: (selected) => ref
          .read(contributionConsentProvider.notifier)
          .setEnabled(enabled: selected),
      itemBuilder: (context) => <PopupMenuEntry<bool>>[
        const PopupMenuItem<bool>(
          enabled: false,
          child: Text('Bidra med treningsbilder'),
        ),
        _item(enabled: true, icon: Icons.cloud_upload, label: 'På'),
        _item(enabled: false, icon: Icons.cloud_off, label: 'Av'),
      ],
    );
  }

  PopupMenuItem<bool> _item({
    required bool enabled,
    required IconData icon,
    required String label,
  }) => PopupMenuItem<bool>(
    key: contributionToggleOption(enabled: enabled),
    value: enabled,
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}
