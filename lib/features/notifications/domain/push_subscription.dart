// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// A browser Web Push subscription (spec 0060).
///
/// The [endpoint] is the push service URL the server posts to; [p256dh] and
/// [auth] are the subscription's encryption keys (base64url, unpadded). These
/// are exactly the values a server needs to send an encrypted web push.
@immutable
class PushSubscription {
  /// Creates a subscription.
  const PushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  /// The push service endpoint URL (unique per browser subscription).
  final String endpoint;

  /// The subscription's public encryption key (base64url, unpadded).
  final String p256dh;

  /// The subscription's auth secret (base64url, unpadded).
  final String auth;

  @override
  bool operator ==(Object other) =>
      other is PushSubscription &&
      other.endpoint == endpoint &&
      other.p256dh == p256dh &&
      other.auth == auth;

  @override
  int get hashCode => Object.hash(endpoint, p256dh, auth);
}
