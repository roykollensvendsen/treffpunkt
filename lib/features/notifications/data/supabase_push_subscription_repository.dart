// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/notifications/data/push_subscription_repository.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';

/// [PushSubscriptionRepository] backed by Supabase (spec 0060).
///
/// Like the other Supabase repositories, it is excluded from automated tests
/// (no real credentials); Row-Level Security confines every row to its owner.
final class SupabasePushSubscriptionRepository
    implements PushSubscriptionRepository {
  /// Creates a repository over the given Supabase client.
  SupabasePushSubscriptionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(PushSubscription subscription) async {
    // user_id defaults to auth.uid() server-side; upsert so re-enabling on the
    // same browser refreshes the keys rather than failing on the endpoint PK.
    await _client.from('push_subscriptions').upsert(<String, dynamic>{
      'endpoint': subscription.endpoint,
      'p256dh': subscription.p256dh,
      'auth': subscription.auth,
    }, onConflict: 'endpoint');
  }

  @override
  Future<void> remove(String endpoint) async {
    await _client.from('push_subscriptions').delete().eq('endpoint', endpoint);
  }
}
