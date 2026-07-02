// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the settings page (spec 0072): it gathers the account,
// appearance, notifications and privacy settings; each control drives its
// existing provider; signing out calls the auth repository.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/notifications/data/push_subscription_repository.dart';
import 'package:treffpunkt/features/notifications/data/web_push.dart';
import 'package:treffpunkt/features/notifications/domain/push_subscription.dart';
import 'package:treffpunkt/features/notifications/presentation/notification_providers.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/settings/presentation/settings_screen.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

import '../../auth/fake_auth_repository.dart';

class _FakeWebPush implements WebPush {
  _FakeWebPush({this.isSupported = true, PushSubscription? existing})
    : _current = existing;

  @override
  final bool isSupported;
  PushSubscription? _current;
  int subscribeCalls = 0;

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
    return _current = _sub;
  }

  @override
  Future<String?> unsubscribe() async {
    final endpoint = _current?.endpoint;
    _current = null;
    return endpoint;
  }
}

ProviderContainer _container({
  FakeAuthRepository? auth,
  _FakeWebPush? webPush,
  InMemoryCompetitionRepository? competitions,
  String vapidKey = 'BPaWpublicKey',
}) => ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      auth ??
          FakeAuthRepository(
            initial: const SignedIn(
              AppUser(id: 'me', email: 'frode@example.no'),
            ),
          ),
    ),
    competitionRepositoryProvider.overrideWithValue(
      competitions ?? InMemoryCompetitionRepository(currentUserId: 'me'),
    ),
    webPushProvider.overrideWithValue(webPush ?? _FakeWebPush()),
    vapidPublicKeyProvider.overrideWithValue(vapidKey),
    pushSubscriptionRepositoryProvider.overrideWithValue(
      InMemoryPushSubscriptionRepository(),
    ),
  ],
);

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(home: SettingsScreen()),
);

/// Pumps the settings page in a tall viewport so every section is laid out
/// (the list is taller than the default 600px test surface).
Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(container));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four sections and the account email', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('Konto'), findsOneWidget);
    expect(find.text('frode@example.no'), findsOneWidget);
    expect(find.text('Utseende'), findsOneWidget);
    expect(find.text('Varsler'), findsOneWidget);
    expect(find.text('Personvern'), findsOneWidget);
    expect(find.byKey(settingsSignOutKey), findsOneWidget);
  });

  testWidgets('selecting a theme writes the theme provider', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(container.read(themeModeProvider), ThemeMode.system);
    await tester.tap(find.byKey(settingsThemeOptionDarkKey));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('the notifications switch subscribes', (tester) async {
    final webPush = _FakeWebPush();
    final container = _container(webPush: webPush);
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.tap(find.byKey(settingsNotificationsKey));
    await tester.pumpAndSettle();

    expect(webPush.subscribeCalls, 1);
    expect(find.text('Varsler er på.'), findsOneWidget);
  });

  testWidgets('an unavailable push shows a disabled tile', (tester) async {
    final container = _container(webPush: _FakeWebPush(isSupported: false));
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.byKey(settingsNotificationsKey), findsNothing);
    expect(find.text('Ikke tilgjengelig i denne nettleseren.'), findsOneWidget);
  });

  testWidgets('the contribution switch flips the consent', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    // Opt-out default is on.
    expect(container.read(contributionConsentProvider).enabled, isTrue);
    await tester.tap(find.byKey(settingsContributionKey));
    await tester.pumpAndSettle();

    expect(container.read(contributionConsentProvider).enabled, isFalse);
  });

  testWidgets('editing the brukernavn saves it (spec 0072)', (tester) async {
    final comp = InMemoryCompetitionRepository(currentUserId: 'me');
    final container = _container(competitions: comp);
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(container.read(displayNameProvider), isEmpty);
    expect(find.text('Ikke satt'), findsOneWidget);

    await tester.tap(find.byKey(settingsUsernameKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(displayNameFieldKey), 'Skarpskytter');
    await tester.tap(find.byKey(displayNameSaveKey));
    await tester.pumpAndSettle();

    // The name is persisted to the profile...
    expect((await comp.fetchProfile('me'))?.displayName, 'Skarpskytter');
    // ...and reflected on the page.
    await container.read(currentProfileProvider.future);
    await tester.pumpAndSettle();
    expect(container.read(displayNameProvider), 'Skarpskytter');
    expect(find.text('Skarpskytter'), findsOneWidget);
  });

  testWidgets('Logg ut signs the user out', (tester) async {
    final auth = FakeAuthRepository(
      initial: const SignedIn(AppUser(id: 'me', email: 'frode@example.no')),
    );
    final container = _container(auth: auth);
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.tap(find.byKey(settingsSignOutKey));
    await tester.pumpAndSettle();

    expect(auth.signOutCallCount, 1);
  });

  testWidgets('Brukerveiledning opens the manual (spec 0097)', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.scrollUntilVisible(find.byKey(helpButtonKey), 200);
    await tester.ensureVisible(find.byKey(helpButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(helpButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(manualPageTileKey('competitions.md')), findsOneWidget);
  });
}
