// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_providers.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

/// Key for the "Innstillinger" app-bar action that opens [SettingsScreen].
const Key settingsButtonKey = ValueKey<String>('settingsButton');

/// Key for the "Logg ut" tile on the settings page.
const Key settingsSignOutKey = ValueKey<String>('settingsSignOut');

/// Key for the "Brukernavn" tile on the settings page (spec 0072).
const Key settingsUsernameKey = ValueKey<String>('settingsUsername');

/// Key for the "follow the system" theme choice on the settings page.
const Key settingsThemeOptionSystemKey = ValueKey<String>(
  'settingsThemeOption-system',
);

/// Key for the "light" theme choice on the settings page.
const Key settingsThemeOptionLightKey = ValueKey<String>(
  'settingsThemeOption-light',
);

/// Key for the "dark" theme choice on the settings page.
const Key settingsThemeOptionDarkKey = ValueKey<String>(
  'settingsThemeOption-dark',
);

/// Key for the notifications switch on the settings page.
const Key settingsNotificationsKey = ValueKey<String>('settingsNotifications');

/// Key for the training-image contribution switch on the settings page.
const Key settingsContributionKey = ValueKey<String>('settingsContribution');

/// An app-bar action (a gear) that opens the settings page (spec 0072).
class SettingsButton extends StatelessWidget {
  /// Creates the settings action.
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: settingsButtonKey,
    icon: const Icon(Icons.settings_outlined),
    tooltip: 'Innstillinger',
    onPressed: () => unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    ),
  );
}

/// One place for the app's settings (spec 0072): account, appearance,
/// notifications and privacy — gathered off the program picker's app bar.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings page.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Innstillinger')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                _SectionHeader('Konto', style: theme.textTheme.titleSmall),
                const _AccountSection(),
                const Divider(),
                _SectionHeader('Utseende', style: theme.textTheme.titleSmall),
                const _ThemeSection(),
                const Divider(),
                _SectionHeader('Varsler', style: theme.textTheme.titleSmall),
                const _NotificationsSection(),
                const Divider(),
                _SectionHeader('Personvern', style: theme.textTheme.titleSmall),
                const _ContributionSection(),
                const Divider(),
                _SectionHeader('Hjelp', style: theme.textTheme.titleSmall),
                ListTile(
                  key: helpButtonKey,
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Brukerveiledning'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: (style ?? const TextStyle()).copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final chosen = await showDisplayNameDialog(context, initial: current);
    if (chosen != null && chosen.isNotEmpty) {
      await saveDisplayName(ref, chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStateChangesProvider).value;
    final email = status is SignedIn ? status.user.email : null;
    final name = ref.watch(displayNameProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          key: settingsUsernameKey,
          leading: const Icon(Icons.person_outline),
          title: const Text('Brukernavn'),
          subtitle: Text(name.isEmpty ? 'Ikke satt' : name),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => unawaited(_editName(context, ref, name)),
        ),
        if (email != null)
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('E-post'),
            subtitle: Text(email),
          ),
        ListTile(
          key: settingsSignOutKey,
          leading: const Icon(Icons.logout),
          title: const Text('Logg ut'),
          onTap: () =>
              unawaited(ref.read(authControllerProvider.notifier).signOut()),
        ),
      ],
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return RadioGroup<ThemeMode>(
      groupValue: mode,
      onChanged: (m) {
        if (m != null) ref.read(themeModeProvider.notifier).select(m);
      },
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RadioListTile<ThemeMode>(
            key: settingsThemeOptionSystemKey,
            value: ThemeMode.system,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: Icon(Icons.brightness_auto),
            title: Text('Følg systemet'),
          ),
          RadioListTile<ThemeMode>(
            key: settingsThemeOptionLightKey,
            value: ThemeMode.light,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: Icon(Icons.light_mode),
            title: Text('Lyst'),
          ),
          RadioListTile<ThemeMode>(
            key: settingsThemeOptionDarkKey,
            value: ThemeMode.dark,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: Icon(Icons.dark_mode),
            title: Text('Mørkt'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webPush = ref.watch(webPushProvider);
    final vapidKey = ref.watch(vapidPublicKeyProvider);
    if (!webPush.isSupported || vapidKey.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.notifications_off_outlined),
        title: Text('Varsler'),
        subtitle: Text('Ikke tilgjengelig i denne nettleseren.'),
        enabled: false,
      );
    }
    final enabled = ref.watch(notificationsControllerProvider).value ?? false;
    return SwitchListTile(
      key: settingsNotificationsKey,
      value: enabled,
      secondary: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off,
      ),
      title: const Text('Push-varsler'),
      subtitle: const Text('Få beskjed om nye meldinger og svar.'),
      onChanged: (_) => unawaited(_toggle(context, ref, enabled: enabled)),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(notificationsControllerProvider.notifier);
    if (enabled) {
      await controller.disable();
      messenger.showSnackBar(const SnackBar(content: Text('Varsler er av.')));
    } else {
      final granted = await controller.enable();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Varsler er på.'
                : 'Du må tillate varsler i nettleseren for å få dem.',
          ),
        ),
      );
    }
  }
}

class _ContributionSection extends ConsumerWidget {
  const _ContributionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      contributionConsentProvider.select((c) => c.enabled),
    );
    return SwitchListTile(
      key: settingsContributionKey,
      value: enabled,
      secondary: Icon(enabled ? Icons.cloud_upload : Icons.cloud_off),
      title: const Text('Bidra med treningsbilder'),
      subtitle: const Text(
        'Del anonyme skivebilder for å forbedre automatisk trefftelling.',
      ),
      onChanged: (value) => ref
          .read(contributionConsentProvider.notifier)
          .setEnabled(enabled: value),
    );
  }
}
