// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the deep-link join (spec 0048): a signed-in opener of a
// `?join&token` link joins and lands on the competitions hub; a bad token is
// reported; no link leaves the home untouched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/join_link.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/join_link_handler.dart';

import '../../auth/fake_auth_repository.dart';

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');

Future<Widget> _app(
  InMemoryCompetitionRepository repo, {
  JoinIntent? intent,
}) async => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(initial: const SignedIn(_me)),
    ),
    competitionRepositoryProvider.overrideWithValue(repo),
    if (intent != null) joinIntentProvider.overrideWithValue(intent),
  ],
  child: const MaterialApp(
    home: JoinLinkHandler(
      child: Scaffold(body: Text('home', key: ValueKey<String>('home'))),
    ),
  ),
);

void main() {
  testWidgets('a signed-in opener of a valid link joins and lands on the hub', (
    tester,
  ) async {
    // An owner made a competition; we open its link as a different user.
    final owner = InMemoryCompetitionRepository(
      currentUserId: 'owner',
      currentEmail: 'owner@example.com',
    );
    await owner.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Klubbmatch',
        program: '25 m NAIS fin',
        ownerId: 'owner',
      ),
    );
    final token = (await owner.joinToken('c1'))!;
    final me = owner.asUser(userId: 'me', email: 'me@example.com');

    await tester.pumpWidget(
      await _app(me, intent: (competitionId: 'c1', token: token)),
    );
    await tester.pumpAndSettle();

    // We joined and landed on the competitions hub.
    expect(
      (await owner.membersOf('c1')).map((m) => m.userId),
      contains('me'),
    );
    expect(find.byType(CompetitionsScreen), findsOneWidget);
    expect(find.text('Du ble med i konkurransen.'), findsOneWidget);
  });

  testWidgets('a bad token is reported and does not navigate', (tester) async {
    final owner = InMemoryCompetitionRepository(currentUserId: 'owner');
    await owner.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Klubbmatch',
        program: '25 m NAIS fin',
        ownerId: 'owner',
      ),
    );
    final me = owner.asUser(userId: 'me', email: 'me@example.com');

    await tester.pumpWidget(
      await _app(me, intent: (competitionId: 'c1', token: 'wrong')),
    );
    await tester.pumpAndSettle();

    expect(
      (await owner.membersOf('c1')).map((m) => m.userId),
      isNot(contains('me')),
    );
    expect(find.byType(CompetitionsScreen), findsNothing);
    expect(find.text('Ugyldig eller utløpt lenke.'), findsOneWidget);
  });

  testWidgets('no link leaves the home untouched', (tester) async {
    final me = InMemoryCompetitionRepository(
      currentUserId: 'me',
      currentEmail: 'me@example.com',
    );
    await tester.pumpWidget(await _app(me));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);
    expect(find.byType(CompetitionsScreen), findsNothing);
  });
}
