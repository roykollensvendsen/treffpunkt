// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';

/// Stores the signed-in user's Web Push subscriptions (spec 0060).
abstract interface class PushSubscriptionRepository {
  /// Saves (upserts by endpoint) the given subscription for the current user.
  Future<void> save(PushSubscription subscription);

  /// Removes the subscription with the given [endpoint].
  Future<void> remove(String endpoint);
}

/// In-memory [PushSubscriptionRepository] for tests and a fresh app.
class InMemoryPushSubscriptionRepository implements PushSubscriptionRepository {
  final Map<String, PushSubscription> _byEndpoint =
      <String, PushSubscription>{};

  /// The currently stored subscriptions (for assertions in tests).
  List<PushSubscription> get saved =>
      List<PushSubscription>.unmodifiable(_byEndpoint.values);

  @override
  Future<void> save(PushSubscription subscription) async =>
      _byEndpoint[subscription.endpoint] = subscription;

  @override
  Future<void> remove(String endpoint) async => _byEndpoint.remove(endpoint);
}
