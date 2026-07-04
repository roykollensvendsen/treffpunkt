// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/notification_sound.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/statistics_screen.dart';

/// The app's five tabs (spec 0097): every top destination one thumb-reach
/// tap with a permanent label. The Hjem tab is the shooting start page; the
/// others are the existing screens unchanged.
class HomeShell extends ConsumerStatefulWidget {
  /// Creates the shell with optional extra app-bar [actions] for the Hjem
  /// tab (e.g. the settings button).
  const HomeShell({this.actions, super.key});

  /// Extra actions shown in the Hjem tab's app bar.
  final List<Widget>? actions;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  /// Switches tab, refreshing the destination's background reads exactly
  /// like the old push-navigation helpers did (specs 0011/0026/0082/0083).
  void _select(int index) {
    switch (index) {
      case 0:
        // Hjem derives «Skyt igjen» from the same history Mine økter shows
        // (spec 0108) — refresh it too, not just the resume cards.
        ref
          ..invalidate(savedRecordingProvider)
          ..invalidate(feltSavedSessionProvider)
          ..invalidate(syncedSessionsProvider)
          ..invalidate(storedPendingProvider)
          ..invalidate(feltHistoryProvider)
          ..invalidate(feltSyncedSessionsProvider);
      case 1:
        ref
          ..invalidate(syncedSessionsProvider)
          ..invalidate(storedPendingProvider)
          ..invalidate(feltHistoryProvider)
          ..invalidate(feltSyncedSessionsProvider);
      case 3:
        ref
          ..invalidate(myCompetitionsProvider)
          ..invalidate(myInvitationsProvider);
      default:
        break;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // The shot sound (spec 0134): a notification arriving while the app is
    // open fires the shot and refreshes the bell badge. The first emission
    // (the initial load) is silent by construction — prev is still loading.
    ref.listen(notificationsStreamProvider, (prev, next) {
      final before = prev?.value;
      final after = next.value;
      if (before == null || after == null) return;
      final knownIds = <String>{for (final n in before) n.id};
      final arrived = after.any((n) => !knownIds.contains(n.id) && n.unread);
      if (arrived) {
        ref.read(notificationSoundProvider).play();
        ref.invalidate(notificationsProvider);
      }
    });
    return Scaffold(
      // Content slides under the frosted navigation bar (spec 0129).
      extendBody: true,
      body: switch (_index) {
        0 => ProgramPickerScreen(actions: widget.actions),
        1 => const MySessionsScreen(),
        2 => const StatisticsScreen(),
        3 => const CompetitionsScreen(),
        _ => const ForumScreen(),
      },
      // A slightly smaller label style so «Konkurranser» fits on one line
      // on narrow phones (spec 0097 fix).
      bottomNavigationBar: FrostedBottomBar(
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
              Theme.of(context).textTheme.labelSmall,
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                key: homeTabKey,
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Hjem',
              ),
              NavigationDestination(
                key: mySessionsButtonKey,
                icon: Icon(Icons.history),
                label: 'Mine økter',
              ),
              NavigationDestination(
                key: statisticsButtonKey,
                icon: Icon(Icons.show_chart),
                label: 'Statistikk',
              ),
              NavigationDestination(
                key: competitionsButtonKey,
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                // «Stevner»: short enough to never wrap on narrow phones
                // (spec 0097 fix); the screen itself stays «Konkurranser».
                label: 'Stevner',
              ),
              NavigationDestination(
                key: forumButtonKey,
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'Forum',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Key for the Hjem destination in the bottom bar (spec 0097), for tests.
const Key homeTabKey = ValueKey<String>('homeTab');
