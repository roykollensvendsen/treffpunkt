// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/notifications/data/web_push_stub.dart'
    if (dart.library.js_interop) 'package:treffpunkt/features/notifications/data/web_push_web.dart'
    as impl;
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';

/// The browser Web Push surface (spec 0060): permission, the service worker,
/// and the push subscription.
///
/// The real implementation (web only) is in `web_push_web.dart` over
/// `package:web` + `dart:js_interop`; off the web — and in tests — the stub
/// reports [isSupported] `false`. A fake drives the widget tests.
abstract interface class WebPush {
  /// Whether this browser can do Web Push (service worker + Push API +
  /// Notifications). Always `false` off the web.
  bool get isSupported;

  /// The current push subscription for this browser, or `null` if none.
  Future<PushSubscription?> currentSubscription();

  /// Requests notification permission and subscribes with [vapidPublicKey]
  /// (registering the service worker). Returns the subscription, or `null` if
  /// the user denied permission or it otherwise failed.
  Future<PushSubscription?> subscribe(String vapidPublicKey);

  /// Unsubscribes this browser. Returns the removed endpoint, or `null` if
  /// there was no subscription.
  Future<String?> unsubscribe();
}

/// The real [WebPush] on the web; an unsupported stub elsewhere and in tests.
WebPush createWebPush() => impl.createWebPush();
