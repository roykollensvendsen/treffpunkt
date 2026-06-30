// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the in-memory push-subscription repository (spec 0060): a saved
// subscription is stored; saving the same endpoint again updates it; removing
// it deletes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/notifications/data/push_subscription_repository.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';

void main() {
  test('saves, updates by endpoint, and removes a subscription', () async {
    final repo = InMemoryPushSubscriptionRepository();
    expect(repo.saved, isEmpty);

    const sub = PushSubscription(
      endpoint: 'https://push.example/abc',
      p256dh: 'key1',
      auth: 'auth1',
    );
    await repo.save(sub);
    expect(repo.saved, <PushSubscription>[sub]);

    // Saving the same endpoint again updates rather than duplicates.
    const refreshed = PushSubscription(
      endpoint: 'https://push.example/abc',
      p256dh: 'key2',
      auth: 'auth2',
    );
    await repo.save(refreshed);
    expect(repo.saved, <PushSubscription>[refreshed]);

    await repo.remove(sub.endpoint);
    expect(repo.saved, isEmpty);
  });
}
