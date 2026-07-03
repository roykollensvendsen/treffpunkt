// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/backup/presentation/backup_section.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_screen.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/settings/presentation/default_place_providers.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

/// Key for the "Innstillinger" app-bar action that opens [SettingsScreen].
const Key settingsButtonKey = ValueKey<String>('settingsButton');

/// Key for the «Slett profilen min» tile (spec 0126), for tests.
const Key settingsDeleteAccountKey = ValueKey<String>(
  'settingsDeleteAccount',
);

/// Key for the confirm action in the delete-account dialog (spec 0126).
const Key confirmDeleteAccountKey = ValueKey<String>('confirmDeleteAccount');

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

/// Key for the "Standard sted" tile on the settings page (spec 0102).
const Key settingsDefaultPlaceKey = ValueKey<String>('settingsDefaultPlace');

/// Key for the text field in the default-place dialog (spec 0102).
const Key settingsDefaultPlaceFieldKey = ValueKey<String>(
  'settingsDefaultPlaceField',
);

/// Key for the "Personlige rekorder" tile on the settings page (spec 0102).
const Key settingsRecordsKey = ValueKey<String>('settingsRecords');

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
                _SectionHeader('Skyting', style: theme.textTheme.titleSmall),
                const _ShootingSection(),
                const Divider(),
                _SectionHeader(
                  'Sikkerhetskopi',
                  style: theme.textTheme.titleSmall,
                ),
                const BackupSection(),
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
        ListTile(
          key: settingsDeleteAccountKey,
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Slett profilen min',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => unawaited(_deleteAccount(context, ref)),
        ),
      ],
    );
  }

  /// Deletes the account after an explicit consequence-listing confirmation
  /// (specs 0126/0096); the auth gate takes over once signed out.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slette profilen din?'),
        content: const Text(
          'Dette sletter kontoen din og alt som er synkronisert til den: '
          'økter og feltrunder, konkurranser du EIER (de forsvinner også '
          'for deltakerne), innleggene dine i forumet og varslene dine. '
          'Handlingen kan ikke angres.\n\n'
          'Data lagret kun på denne enheten blir liggende her — ta gjerne '
          'en sikkerhetskopi først (Innstillinger → Sikkerhetskopi).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: confirmDeleteAccountKey,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Slett profilen min'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).deleteAccount();
  }
}

/// The shooting defaults (spec 0102): the default place that pre-fills the
/// setup step, and the personal-record baselines.
class _ShootingSection extends ConsumerWidget {
  const _ShootingSection();

  Future<void> _editPlace(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _DefaultPlaceDialog(current: current),
    );
    // An emptied field clears the default; the notifier trims and nulls it.
    if (saved != null) ref.read(defaultPlaceProvider.notifier).set(saved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(defaultPlaceProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          key: settingsDefaultPlaceKey,
          leading: const Icon(Icons.place_outlined),
          title: const Text('Standard sted'),
          subtitle: Text(place ?? 'Ikke satt'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => unawaited(_editPlace(context, ref, place)),
        ),
        ListTile(
          key: settingsRecordsKey,
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('Personlige rekorder'),
          subtitle: const Text('Startverdier og gjeldende pers per øvelse'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PersonalRecordsScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The default-place editor (spec 0102): pops with the typed text on Lagre
/// (blank clears the default), or null on Avbryt. Owns its controller so it
/// outlives the route's exit animation.
class _DefaultPlaceDialog extends StatefulWidget {
  const _DefaultPlaceDialog({required this.current});

  final String? current;

  @override
  State<_DefaultPlaceDialog> createState() => _DefaultPlaceDialogState();
}

class _DefaultPlaceDialogState extends State<_DefaultPlaceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Standard sted'),
    content: TextField(
      key: settingsDefaultPlaceFieldKey,
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Sted',
        hintText: 'F.eks. banen du trener på',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Lagre'),
      ),
    ],
  );
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
