// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the on-sign-in profile upsert (spec 0010): when the user is signed
// in, profileSyncProvider upserts their profile once; a repository that fails
// must never break sign-in.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';

import '../../auth/fake_auth_repository.dart';

void main() {
  test('upserts the signed-in user profile once', () async {
    final repo = _RecordingCompetitionRepository();
    final auth = FakeAuthRepository(
      initial: const SignedIn(
        AppUser(id: 'u1', email: 'a@b.no', displayName: 'Alice'),
      ),
    );
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        competitionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    container.read(profileSyncProvider); // build → fires immediately
    await Future<void>.delayed(Duration.zero); // let the upsert microtask run

    expect(repo.upserted, <Profile>[
      const Profile(id: 'u1', displayName: 'Alice'),
    ]);
  });

  test('a failing profile upsert does not break sign-in', () async {
    final auth = FakeAuthRepository(
      initial: const SignedIn(AppUser(id: 'u1')),
    );
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        competitionRepositoryProvider.overrideWithValue(
          _ThrowingCompetitionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Building the provider must not throw, and the rejected upsert future is
    // handled (caught), so no unhandled async error surfaces.
    container.read(profileSyncProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authStateChangesProvider).value, isA<SignedIn>());
  });
}

/// Records the profiles passed to [upsertOwnProfile]; other methods are unused.
class _RecordingCompetitionRepository implements CompetitionRepository {
  final List<Profile> upserted = <Profile>[];

  @override
  Future<void> upsertOwnProfile(Profile profile) async => upserted.add(profile);

  @override
  Future<void> createCompetition(Competition competition) async =>
      throw UnimplementedError();
  @override
  Future<List<Competition>> listMine() async => throw UnimplementedError();
  @override
  Future<void> invite(String competitionId, String email) async =>
      throw UnimplementedError();
  @override
  Future<List<Profile>> listShooters() async => throw UnimplementedError();
  @override
  Future<void> inviteUser(String competitionId, String userId) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionInvitation>> listMyInvitations() async =>
      throw UnimplementedError();
  @override
  Future<void> acceptInvitation(String competitionId) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionMember>> membersOf(String competitionId) async =>
      throw UnimplementedError();
  @override
  Future<void> submitResult(CompetitionResult result) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionResult>> resultsOf(String competitionId) async =>
      throw UnimplementedError();
  @override
  Stream<List<CompetitionResult>> watchResults(String competitionId) =>
      throw UnimplementedError();
}

/// A repository whose profile upsert always fails (a misconfigured backend).
class _ThrowingCompetitionRepository extends _RecordingCompetitionRepository {
  @override
  Future<void> upsertOwnProfile(Profile profile) async =>
      throw const CompetitionSyncException('boom');
}
