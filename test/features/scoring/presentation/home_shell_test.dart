// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the bottom-navigation shell (spec 0097).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/home_shell.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/statistics_screen.dart';

Widget _app() => ProviderScope(
  overrides: [sessionStoreProvider.overrideWithValue(InMemorySessionStore())],
  child: const MaterialApp(home: HomeShell()),
);

void main() {
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
      'Konkurranser',
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
