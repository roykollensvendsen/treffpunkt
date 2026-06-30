// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/config/app_config.dart';
import 'package:treffpunkt/features/notifications/data/push_subscription_repository.dart';
import 'package:treffpunkt/features/notifications/data/web_push.dart';

/// The browser Web Push surface (spec 0060). Defaults to the real one (the
/// conditional import yields an unsupported stub off the web and in tests);
/// tests override it with a fake.
final webPushProvider = Provider<WebPush>((ref) => createWebPush());

/// Where push subscriptions are stored. Defaults to in-memory so tests and a
/// fresh app never touch real storage; `main()` overrides it with Supabase.
final pushSubscriptionRepositoryProvider = Provider<PushSubscriptionRepository>(
  (ref) => InMemoryPushSubscriptionRepository(),
);

/// The VAPID public key (build-time config). Empty hides the notifications
/// control. A provider so tests can supply a key without a `--dart-define`.
final vapidPublicKeyProvider = Provider<String>(
  (ref) => AppConfig.vapidPublicKey,
);

/// Whether notifications are currently on for this browser, and the actions to
/// turn them on/off (spec 0060).
class NotificationsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final webPush = ref.watch(webPushProvider);
    final vapidKey = ref.watch(vapidPublicKeyProvider);
    if (!webPush.isSupported || vapidKey.isEmpty) return false;
    return (await webPush.currentSubscription()) != null;
  }

  /// Asks for permission, subscribes and stores the subscription. Returns
  /// `true` if notifications are now on, `false` if permission was denied.
  Future<bool> enable() async {
    final webPush = ref.read(webPushProvider);
    final vapidKey = ref.read(vapidPublicKeyProvider);
    final subscription = await webPush.subscribe(vapidKey);
    if (subscription == null) {
      state = const AsyncData<bool>(false);
      return false;
    }
    await ref.read(pushSubscriptionRepositoryProvider).save(subscription);
    state = const AsyncData<bool>(true);
    return true;
  }

  /// Unsubscribes this browser and removes the stored subscription.
  Future<void> disable() async {
    final webPush = ref.read(webPushProvider);
    final endpoint = await webPush.unsubscribe();
    if (endpoint != null) {
      await ref.read(pushSubscriptionRepositoryProvider).remove(endpoint);
    }
    state = const AsyncData<bool>(false);
  }
}

/// Exposes [NotificationsController].
final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, bool>(
      NotificationsController.new,
    );
