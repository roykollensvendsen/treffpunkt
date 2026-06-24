// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the in-memory competition repository (spec 0010): create is
// idempotent and auto-adds the owner as a member; listMine returns owned +
// joined and excludes others'; invite + accept route a user into a competition;
// membersOf attaches profiles. The cross-user flow uses one shared store
// via asUser().
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

Competition _comp(String id, {required String ownerId, String name = 'Cup'}) =>
    Competition(id: id, name: name, program: '25 m NAIS fin', ownerId: ownerId);

void main() {
  test('create is idempotent and auto-adds the owner as a member', () async {
    final repo = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    await repo.createCompetition(_comp('c1', ownerId: 'alice'));
    await repo.createCompetition(_comp('c1', ownerId: 'alice')); // again

    final mine = await repo.listMine();
    expect(mine.map((c) => c.id), <String>['c1']); // exactly one
    final members = await repo.membersOf('c1');
    expect(members.map((m) => m.userId), <String>['alice']);
  });

  test('listMine returns owned and joined, excludes others', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    await alice.createCompetition(_comp('mine', ownerId: 'alice'));
    // A competition owned by someone else that Alice is not in.
    await alice.createCompetition(_comp('theirs', ownerId: 'bob'));

    final mine = await alice.listMine();
    expect(mine.map((c) => c.id), <String>['mine']);
  });

  test('invite then accept routes the invitee into the competition', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    final bob = alice.asUser(userId: 'bob', email: 'bob@example.com');

    await alice.createCompetition(_comp('c1', ownerId: 'alice'));
    await alice.invite('c1', 'Bob@Example.com'); // mixed case

    // Bob sees the pending invitation, with the competition attached.
    final invites = await bob.listMyInvitations();
    expect(invites.map((i) => i.competitionId), <String>['c1']);
    expect(invites.single.competition?.name, 'Cup');
    // Alice (the inviter) is not the invitee, so she has none.
    expect(await alice.listMyInvitations(), isEmpty);

    // Before accepting, Bob is not a member.
    expect(await bob.listMine(), isEmpty);

    await bob.acceptInvitation('c1');

    expect((await bob.listMine()).map((c) => c.id), <String>['c1']);
    final members = await bob.membersOf('c1');
    expect(members.map((m) => m.userId).toSet(), <String>{'alice', 'bob'});
    // The invitation is no longer pending, so accepting again fails (matching
    // the accept_invitation RPC, which requires a pending invitation).
    expect(await bob.listMyInvitations(), isEmpty);
    await expectLater(
      bob.acceptInvitation('c1'),
      throwsA(isA<CompetitionSyncException>()),
    );
  });

  test('listShooters returns the registered shooters', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    final bob = alice.asUser(userId: 'bob', email: 'bob@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));

    final shooters = await alice.listShooters();
    expect(
      shooters.map((p) => p.displayName).toSet(),
      <String>{'Alice', 'Bob'},
    );
  });

  test('inviteUser routes a picked shooter into the competition', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    final bob = alice.asUser(userId: 'bob', email: 'Bob@Example.com');
    // Bob syncs his profile on sign-in, so the backend knows his email.
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));
    await alice.createCompetition(_comp('c1', ownerId: 'alice'));

    // Alice invites Bob by picking him — she never handles his email.
    await alice.inviteUser('c1', 'bob');

    final invites = await bob.listMyInvitations();
    expect(invites.map((i) => i.competitionId), <String>['c1']);
    await bob.acceptInvitation('c1');
    final members = await bob.membersOf('c1');
    expect(members.map((m) => m.userId).toSet(), <String>{'alice', 'bob'});
  });

  test('inviteUser throws for a shooter with no known email', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    await alice.createCompetition(_comp('c1', ownerId: 'alice'));
    // No profile sync for 'ghost', so the backend has no email to invite.
    await expectLater(
      alice.inviteUser('c1', 'ghost'),
      throwsA(isA<CompetitionSyncException>()),
    );
  });

  test('accepting without a pending invitation throws', () async {
    final repo = InMemoryCompetitionRepository(
      currentUserId: 'bob',
      currentEmail: 'bob@example.com',
    );
    await expectLater(
      repo.acceptInvitation('nope'),
      throwsA(isA<CompetitionSyncException>()),
    );
  });

  test('membersOf attaches profiles when known', () async {
    final alice = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await alice.createCompetition(_comp('c1', ownerId: 'alice'));

    final members = await alice.membersOf('c1');
    expect(members.single.profile?.displayName, 'Alice');
  });

  test('submitResult is idempotent by id (first submission wins)', () async {
    final repo = InMemoryCompetitionRepository(
      currentUserId: 'alice',
      currentEmail: 'alice@example.com',
    );
    await repo.submitResult(_result('s1', competitionId: 'c1', total: 580));
    // A re-submit of the same session id is a no-op (the score is unchanged).
    await repo.submitResult(_result('s1', competitionId: 'c1', total: 999));

    final results = await repo.resultsOf('c1');
    expect(results.map((r) => r.id), <String>['s1']);
    expect(results.single.total, 580);
    // The acting user is stamped (the DB defaults user_id to auth.uid()).
    expect(results.single.userId, 'alice');
  });

  test('resultsOf is sorted best-first with submitter profiles', () async {
    final repo = InMemoryCompetitionRepository(currentUserId: 'host');
    await repo.upsertOwnProfile(const Profile(id: 'a', displayName: 'Alice'));
    await repo.upsertOwnProfile(const Profile(id: 'b', displayName: 'Bob'));
    // Same total → the one with more inner tens ranks higher.
    await repo.submitResult(
      _result('r-low', competitionId: 'c1', total: 560, userId: 'a'),
    );
    await repo.submitResult(
      _result(
        'r-top',
        competitionId: 'c1',
        total: 580,
        innerTens: 8,
        userId: 'b',
      ),
    );
    await repo.submitResult(
      _result(
        'r-mid',
        competitionId: 'c1',
        total: 580,
        innerTens: 3,
        userId: 'a',
      ),
    );

    final results = await repo.resultsOf('c1');
    expect(results.map((r) => r.id), <String>['r-top', 'r-mid', 'r-low']);
    expect(results.first.profile?.displayName, 'Bob');
  });

  test('watchResults emits the board, then re-emits after a submit', () async {
    final repo = InMemoryCompetitionRepository(currentUserId: 'alice');
    final expectation = expectLater(
      repo.watchResults('c1'),
      emitsInOrder(<Object>[
        predicate<List<CompetitionResult>>((l) => l.isEmpty, 'empty board'),
        predicate<List<CompetitionResult>>(
          (l) => l.length == 1 && l.first.id == 's1',
          'one result',
        ),
      ]),
    );
    // Let the stream emit the initial empty board and subscribe to changes
    // before the submit fires.
    await Future<void>.delayed(Duration.zero);
    await repo.submitResult(_result('s1', competitionId: 'c1', total: 580));
    await expectation;
  });
}

CompetitionResult _result(
  String id, {
  required String competitionId,
  required int total,
  int innerTens = 0,
  String? userId,
}) => CompetitionResult(
  id: id,
  competitionId: competitionId,
  userId: userId,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 600,
  innerTens: innerTens,
  payload: const <String, dynamic>{},
);
