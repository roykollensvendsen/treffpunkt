// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:treffpunkt/features/notifications/data/web_push.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';
import 'package:web/web.dart' as web;

/// The dedicated, cache-free push service worker (spec 0060). Relative so it
/// resolves under the app's base href and takes that scope.
const String _serviceWorkerUrl = 'push_sw.js';

/// The real Web Push implementation over `package:web` + `dart:js_interop`.
WebPush createWebPush() => const _WebPushImpl();

class _WebPushImpl implements WebPush {
  const _WebPushImpl();

  @override
  bool get isSupported =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      (web.window.navigator as JSObject).has('serviceWorker');

  @override
  Future<PushSubscription?> currentSubscription() async {
    if (!isSupported) return null;
    final registration = await web.window.navigator.serviceWorker
        .getRegistration(_serviceWorkerUrl)
        .toDart;
    if (registration == null) return null;
    final subscription = await registration.pushManager
        .getSubscription()
        .toDart;
    return subscription == null ? null : _toDomain(subscription);
  }

  @override
  Future<PushSubscription?> subscribe(String vapidPublicKey) async {
    if (!isSupported) return null;
    final permission =
        (await web.Notification.requestPermission().toDart).toDart;
    if (permission != 'granted') return null;
    final registration = await web.window.navigator.serviceWorker
        .register(_serviceWorkerUrl.toJS)
        .toDart;
    final subscription = await registration.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _decodeBase64Url(vapidPublicKey).toJS,
          ),
        )
        .toDart;
    return _toDomain(subscription);
  }

  @override
  Future<String?> unsubscribe() async {
    if (!isSupported) return null;
    final registration = await web.window.navigator.serviceWorker
        .getRegistration(_serviceWorkerUrl)
        .toDart;
    if (registration == null) return null;
    final subscription = await registration.pushManager
        .getSubscription()
        .toDart;
    if (subscription == null) return null;
    final endpoint = subscription.endpoint;
    await subscription.unsubscribe().toDart;
    return endpoint;
  }

  PushSubscription _toDomain(web.PushSubscription subscription) =>
      PushSubscription(
        endpoint: subscription.endpoint,
        p256dh: _encodeKey(subscription, 'p256dh'),
        auth: _encodeKey(subscription, 'auth'),
      );

  /// Reads a subscription key as unpadded base64url (the form web-push servers
  /// expect).
  String _encodeKey(web.PushSubscription subscription, String name) {
    final key = subscription.getKey(name);
    if (key == null) return '';
    final bytes = key.toDart.asUint8List();
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decodes an unpadded base64url string (the VAPID public key) to bytes.
  Uint8List _decodeBase64Url(String value) {
    final padding = (4 - value.length % 4) % 4;
    return base64Url.decode(value + ('=' * padding));
  }
}
