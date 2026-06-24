// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the competitions UI (spec 0011): the empty state; creating a
// competition makes it appear in "Mine konkurranser"; accepting an invitation
// moves it into the list; and the owner can invite someone by email.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';

import '../../auth/fake_auth_repository.dart';

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');

Widget _app(
  InMemoryCompetitionRepository repo, {
  String newId = 'new-1',
  Widget home = const CompetitionsScreen(),
}) {
  final auth = FakeAuthRepository(initial: const SignedIn(_me));
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      competitionRepositoryProvider.overrideWithValue(repo),
      competitionIdGeneratorProvider.overrideWithValue(() => newId),
    ],
    child: MaterialApp(home: home),
  );
}

InMemoryCompetitionRepository _meRepo() => InMemoryCompetitionRepository(
  currentUserId: 'me',
  currentEmail: 'me@example.com',
);

void main() {
  testWidgets('shows the empty state with no competitions', (tester) async {
    await tester.pumpWidget(_app(_meRepo()));
    await tester.pumpAndSettle();
    expect(find.byKey(noCompetitionsKey), findsOneWidget);
  });

  testWidgets('creating a competition makes it appear in the list', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_meRepo(), newId: 'created-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(newCompetitionButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(competitionNameFieldKey), 'Klubbmatch');
    await tester.tap(find.byKey(createCompetitionSubmitKey));
    await tester.pumpAndSettle();

    // Back on the hub, the new competition is listed.
    expect(find.byKey(competitionCard('created-1')), findsOneWidget);
    expect(find.text('Klubbmatch'), findsOneWidget);
  });

  testWidgets('accepting an invitation moves it into my competitions', (
    tester,
  ) async {
    final repo = _meRepo();
    // Another user owns a competition and invites me.
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Alice Cup',
        program: '25 m NAIS fin',
        ownerId: 'alice',
      ),
    );
    await alice.invite('c1', 'me@example.com');

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // The invitation is offered; the competition is not yet in my list.
    expect(find.byKey(acceptInvitationKey('c1')), findsOneWidget);
    expect(find.byKey(competitionCard('c1')), findsNothing);

    await tester.tap(find.byKey(acceptInvitationKey('c1')));
    await tester.pumpAndSettle();

    // After accepting, it moves into my competitions and the invite is gone.
    expect(find.byKey(acceptInvitationKey('c1')), findsNothing);
    expect(find.byKey(competitionCard('c1')), findsOneWidget);
    expect(find.text('Alice Cup'), findsOneWidget);
  });

  testWidgets('the owner can invite someone by email', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(inviteEmailFieldKey),
      'bob@example.com',
    );
    await tester.tap(find.byKey(inviteSubmitKey));
    await tester.pumpAndSettle();

    // The invitation reached the store: Bob now has a pending invitation.
    final bob = repo.asUser(userId: 'bob', email: 'bob@example.com');
    final invitations = await bob.listMyInvitations();
    expect(invitations.map((i) => i.competitionId), <String>['c1']);
  });
}
