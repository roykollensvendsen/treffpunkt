// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the notifications toggle (spec 0060), driven by a fake
// WebPush: turning it on subscribes and stores the subscription; a denied
// permission stores nothing; turning it off removes it; an unsupported browser
// or empty VAPID key hides the control.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/notifications/data/push_subscription_repository.dart';
import 'package:treffpunkt/features/notifications/data/web_push.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_providers.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_toggle_button.dart';

class FakeWebPush implements WebPush {
  FakeWebPush({
    this.isSupported = true,
    this.willGrant = true,
    PushSubscription? existing,
  }) : _current = existing;

  @override
  final bool isSupported;
  final bool willGrant;
  PushSubscription? _current;
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;

  static const _sub = PushSubscription(
    endpoint: 'https://push.example/abc',
    p256dh: 'p',
    auth: 'a',
  );

  @override
  Future<PushSubscription?> currentSubscription() async => _current;

  @override
  Future<PushSubscription?> subscribe(String vapidPublicKey) async {
    subscribeCalls++;
    if (!willGrant) return null;
    return _current = _sub;
  }

  @override
  Future<String?> unsubscribe() async {
    unsubscribeCalls++;
    final endpoint = _current?.endpoint;
    _current = null;
    return endpoint;
  }
}

Widget _app({
  required FakeWebPush webPush,
  required InMemoryPushSubscriptionRepository repo,
  String vapidKey = 'BPaWpublicKey',
}) => ProviderScope(
  overrides: [
    webPushProvider.overrideWithValue(webPush),
    pushSubscriptionRepositoryProvider.overrideWithValue(repo),
    vapidPublicKeyProvider.overrideWithValue(vapidKey),
  ],
  child: const MaterialApp(
    home: Scaffold(body: Row(children: [NotificationToggleButton()])),
  ),
);

void main() {
  testWidgets('turning notifications on subscribes and stores it', (
    tester,
  ) async {
    final webPush = FakeWebPush();
    final repo = InMemoryPushSubscriptionRepository();
    await tester.pumpWidget(_app(webPush: webPush, repo: repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    await tester.tap(find.byKey(notificationsToggleKey));
    await tester.pumpAndSettle();

    expect(webPush.subscribeCalls, 1);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.endpoint, 'https://push.example/abc');
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    expect(find.text('Varsler er på.'), findsOneWidget);
  });

  testWidgets('denied permission stores nothing and explains', (tester) async {
    final webPush = FakeWebPush(willGrant: false);
    final repo = InMemoryPushSubscriptionRepository();
    await tester.pumpWidget(_app(webPush: webPush, repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(notificationsToggleKey));
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty);
    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    expect(
      find.text('Du må tillate varsler i nettleseren for å få dem.'),
      findsOneWidget,
    );
  });

  testWidgets('turning notifications off removes the subscription', (
    tester,
  ) async {
    const existing = PushSubscription(
      endpoint: 'https://push.example/abc',
      p256dh: 'p',
      auth: 'a',
    );
    final webPush = FakeWebPush(existing: existing);
    final repo = InMemoryPushSubscriptionRepository();
    await repo.save(existing);
    await tester.pumpWidget(_app(webPush: webPush, repo: repo));
    await tester.pumpAndSettle();

    // Starts enabled because there is already a subscription.
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);

    await tester.tap(find.byKey(notificationsToggleKey));
    await tester.pumpAndSettle();

    expect(webPush.unsubscribeCalls, 1);
    expect(repo.saved, isEmpty);
    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    expect(find.text('Varsler er av.'), findsOneWidget);
  });

  testWidgets('an unsupported browser hides the control', (tester) async {
    final repo = InMemoryPushSubscriptionRepository();
    await tester.pumpWidget(
      _app(webPush: FakeWebPush(isSupported: false), repo: repo),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(notificationsToggleKey), findsNothing);
  });

  testWidgets('an empty VAPID key hides the control', (tester) async {
    final repo = InMemoryPushSubscriptionRepository();
    await tester.pumpWidget(
      _app(webPush: FakeWebPush(), repo: repo, vapidKey: ''),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(notificationsToggleKey), findsNothing);
  });
}
