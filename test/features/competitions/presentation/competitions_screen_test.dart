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
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

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

  testWidgets('owner picks a registered shooter to invite, hiding self and '
      'members', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    final bob = repo.asUser(userId: 'bob', email: 'bob@example.com');
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));
    // Alice is already a member, so she must not appear in the picker.
    await repo.inviteUser('c1', 'alice');
    await alice.acceptInvitation('c1');

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    // Bob (registered non-member) is offered; the owner and the member are not.
    expect(find.byKey(shooterPickerKey), findsOneWidget);
    expect(find.byKey(shooterTileKey('bob')), findsOneWidget);
    expect(find.byKey(shooterTileKey('me')), findsNothing);
    expect(find.byKey(shooterTileKey('alice')), findsNothing);

    await tester.tap(find.byKey(inviteShooterButtonKey('bob')));
    await tester.pumpAndSettle();

    // Picking Bob invited him — no email was ever typed or shown.
    final invitations = await bob.listMyInvitations();
    expect(invitations.map((i) => i.competitionId), <String>['c1']);
  });

  testWidgets('a non-owner sees no invite controls', (tester) async {
    final repo = _meRepo();
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    const competition = Competition(
      id: 'c1',
      name: 'Alice Cup',
      program: '25 m NAIS fin',
      ownerId: 'alice',
    );
    await alice.createCompetition(competition);
    await alice.invite('c1', 'me@example.com');
    await repo.acceptInvitation('c1'); // me joins as a member, not the owner

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(shooterPickerKey), findsNothing);
    expect(find.byKey(inviteEmailFieldKey), findsNothing);
  });

  testWidgets('the detail shows the scoreboard, best first', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await repo.submitResult(_res('r-me', user: 'me', total: 560));
    await alice.submitResult(_res('r-alice', user: 'alice', total: 580));

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(noResultsKey), findsNothing);
    expect(find.byKey(resultRowKey('r-alice')), findsOneWidget);
    expect(find.byKey(resultRowKey('r-me')), findsOneWidget);
    // Alice's name shows on her scoreboard row (she also appears in the invite
    // picker as a registered non-member, so scope the check to the row).
    expect(
      find.descendant(
        of: find.byKey(resultRowKey('r-alice')),
        matching: find.text('Alice'),
      ),
      findsOneWidget,
    );
    expect(find.text('580 / 600'), findsOneWidget);
    // Best first: Alice's row sits above Me's.
    final aliceTop = tester.getTopLeft(find.byKey(resultRowKey('r-alice'))).dy;
    final meTop = tester.getTopLeft(find.byKey(resultRowKey('r-me'))).dy;
    expect(aliceTop, lessThan(meTop));
  });

  testWidgets('the scoreboard updates live when a result is submitted', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(noResultsKey), findsOneWidget); // empty board

    // Another participant submits — the live stream updates the board with no
    // reopen.
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await alice.submitResult(_res('r-alice', user: 'alice', total: 575));
    await tester.pumpAndSettle();

    expect(find.byKey(noResultsKey), findsNothing);
    expect(find.byKey(resultRowKey('r-alice')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('Skyt nå opens setup for the competition program', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(shootForCompetitionKey));
    await tester.pumpAndSettle();

    // The setup step for the competition's fixed program is shown.
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, '10 m Air Pistol'), findsOneWidget);
  });
}

CompetitionResult _res(
  String id, {
  required String user,
  required int total,
}) => CompetitionResult(
  id: id,
  competitionId: 'c1',
  userId: user,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 600,
  innerTens: 0,
  payload: const <String, dynamic>{},
);
