// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the notification center (spec 0094).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/notifications/data/notifications_repository.dart';
import 'package:treffpunkt/features/notifications/domain/app_notification.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

AppNotification _invitation(String id, {DateTime? at}) => AppNotification(
  id: id,
  kind: AppNotificationKind.invitation,
  title: 'Invitasjon: Klubbmesterskap',
  body: 'Du er invitert til å bli med.',
  createdAt: at ?? DateTime.utc(2026, 7, 2, 12),
  competitionId: 'c1',
);

Widget _app(NotificationsRepository repository, {Widget? home}) =>
    ProviderScope(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
      ],
      child: MaterialApp(home: home ?? const NotificationsScreen()),
    );

void main() {
  testWidgets('the bell shows the unread count and opens Varsler (0094)', (
    tester,
  ) async {
    final repository = InMemoryNotificationsRepository(
      seeded: <AppNotification>[
        _invitation('n1'),
        _invitation('n2', at: DateTime.utc(2026, 6, 30)),
      ],
    );
    await tester.pumpWidget(
      _app(repository, home: const ProgramPickerScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(notificationsBellKey), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // the badge

    await tester.tap(find.byKey(notificationsBellKey));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Invitasjon: Klubbmesterskap'), findsNWidgets(2));
  });

  testWidgets('tapping a varsel marks it read and opens its target (0094)', (
    tester,
  ) async {
    final repository = InMemoryNotificationsRepository(
      seeded: <AppNotification>[_invitation('n1')],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(notificationTileKey('n1')));
    await tester.pumpAndSettle();

    // Navigated straight to the competitions hub, and the row is read.
    expect(find.byType(CompetitionsScreen), findsOneWidget);
    final list = await repository.list();
    expect(list.single.unread, isFalse);
  });

  testWidgets('marker alle som lest clears the unread state (0094)', (
    tester,
  ) async {
    final repository = InMemoryNotificationsRepository(
      seeded: <AppNotification>[_invitation('n1'), _invitation('n2')],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(markAllReadKey));
    await tester.pumpAndSettle();

    final list = await repository.list();
    expect(list.every((n) => !n.unread), isTrue);
  });

  testWidgets('no notifications shows the calm empty state (0094)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(InMemoryNotificationsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(noNotificationsKey), findsOneWidget);
  });
}
