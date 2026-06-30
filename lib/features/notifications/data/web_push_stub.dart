// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/notifications/data/web_push.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';

/// Off-web (and test) [WebPush]: push is unsupported, so the notifications
/// control is hidden (spec 0060).
WebPush createWebPush() => const _UnsupportedWebPush();

class _UnsupportedWebPush implements WebPush {
  const _UnsupportedWebPush();

  @override
  bool get isSupported => false;

  @override
  Future<PushSubscription?> currentSubscription() async => null;

  @override
  Future<PushSubscription?> subscribe(String vapidPublicKey) async => null;

  @override
  Future<String?> unsubscribe() async => null;
}
