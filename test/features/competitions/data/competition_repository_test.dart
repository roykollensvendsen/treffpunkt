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
}
