// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the bottom-navigation shell (spec 0097).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/notification_sound.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/notifications/data/notifications_repository.dart';
import 'package:treffpunkt/features/notifications/domain/app_notification.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/home_shell.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/statistics_screen.dart';

Widget _app({
  InMemoryNotificationsRepository? notifications,
  _FakeSound? sound,
}) => ProviderScope(
  overrides: [
    sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
    if (notifications != null)
      notificationsRepositoryProvider.overrideWithValue(notifications),
    if (sound != null) notificationSoundProvider.overrideWithValue(sound),
  ],
  child: const MaterialApp(home: HomeShell()),
);

/// Counts shots fired (spec 0134).
class _FakeSound implements NotificationSound {
  int plays = 0;

  @override
  void play() => plays++;
}

void main() {
  testWidgets('an arriving notification fires the shot (spec 0134)', (
    tester,
  ) async {
    final repo = InMemoryNotificationsRepository(
      seeded: [
        AppNotification(
          id: 'old',
          kind: AppNotificationKind.forumReply,
          title: 'Gammelt svar',
          body: '',
          createdAt: DateTime(2026, 7),
        ),
      ],
    );
    final sound = _FakeSound();
    await tester.pumpWidget(_app(notifications: repo, sound: sound));
    await tester.pumpAndSettle();

    // The initial load — old notifications included — is silent.
    expect(sound.plays, 0);

    // A new notification arrives while the app is open: one shot, and the
    // bell badge updates without a manual refresh.
    await repo.push(
      AppNotification(
        id: 'fresh',
        kind: AppNotificationKind.mention,
        title: 'Kari nevnte deg',
        body: '',
        createdAt: DateTime(2026, 7, 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(sound.plays, 1);
    expect(find.text('2'), findsOneWidget); // the badge count

    // Nothing new → no extra shot.
    await tester.pumpAndSettle();
    expect(sound.plays, 1);
  });

  testWidgets('the edge bars are frosted and content extends (0129)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The shell's navigation bar sits on frosted glass and the body
    // extends beneath it; the Hjem tab's app bar is frosted too, with the
    // body behind it.
    expect(find.byType(FrostedBottomBar), findsOneWidget);
    final shell = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(shell.extendBody, isTrue);
    expect(find.byType(FrostedAppBar), findsOneWidget);
    final inner = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(ProgramPickerScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(inner.extendBodyBehindAppBar, isTrue);
    expect(find.byType(BackdropFilter), findsNWidgets(2));
  });

  testWidgets('tab FABs float above the frosted navbar (spec 0131)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Forum: «Ny tråd» must sit clear of the navigation bar, not behind it.
    await tester.tap(find.byKey(forumButtonKey));
    await tester.pumpAndSettle();
    final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
    final fab = find.byKey(newThreadButtonKey);
    expect(fab, findsOneWidget);
    expect(tester.getBottomLeft(fab).dy, lessThanOrEqualTo(navTop));

    // Stevner: «Ny konkurranse» likewise.
    await tester.tap(find.byKey(competitionsButtonKey));
    await tester.pumpAndSettle();
    final fab2 = find.byKey(newCompetitionButtonKey);
    expect(fab2, findsOneWidget);
    expect(tester.getBottomLeft(fab2).dy, lessThanOrEqualTo(navTop));
  });

  testWidgets('the bar shows five labelled destinations (spec 0097)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in [
      'Hjem',
      'Mine økter',
      'Statistikk',
      'Stevner',
      'Forum',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Hjem is the shooting start page.
    expect(find.byType(ProgramPickerScreen), findsOneWidget);
    expect(find.byKey(notificationsBellKey), findsOneWidget);
  });

  testWidgets('each destination opens its screen (spec 0097)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mySessionsButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(MySessionsScreen), findsOneWidget);

    await tester.tap(find.byKey(statisticsButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);

    await tester.tap(find.byKey(competitionsButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(CompetitionsScreen), findsOneWidget);

    await tester.tap(find.byKey(forumButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(ForumScreen), findsOneWidget);

    await tester.tap(find.byKey(homeTabKey));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramPickerScreen), findsOneWidget);
  });
}
