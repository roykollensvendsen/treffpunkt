// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_providers.dart';

/// Key for the notifications app-bar action, used by tests (spec 0060).
const Key notificationsToggleKey = ValueKey<String>('notificationsToggle');

/// An app-bar action (a bell) to turn Web Push notifications on or off
/// (spec 0060).
///
/// Hidden where push cannot work — a browser without the Push API, or no VAPID
/// key configured — so the user never meets a dead button. Reflects
/// [notificationsControllerProvider]; toggling subscribes/unsubscribes and
/// confirms with a snackbar.
class NotificationToggleButton extends ConsumerWidget {
  /// Creates the notifications action.
  const NotificationToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webPush = ref.watch(webPushProvider);
    final vapidKey = ref.watch(vapidPublicKeyProvider);
    if (!webPush.isSupported || vapidKey.isEmpty) {
      return const SizedBox.shrink();
    }
    final enabled = ref.watch(notificationsControllerProvider).value ?? false;
    return IconButton(
      key: notificationsToggleKey,
      tooltip: 'Varsler',
      icon: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_off,
      ),
      onPressed: () => _toggle(context, ref, enabled: enabled),
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Varsler er av.')),
      );
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
