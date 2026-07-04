// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the bottom-navigation shell (spec 0097).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
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
