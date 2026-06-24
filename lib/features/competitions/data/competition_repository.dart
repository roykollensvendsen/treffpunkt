// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

/// Thrown when a competition read fails, or a foreground write the user is
/// waiting on (create / invite / accept) cannot complete — a missing table,
/// denied permission, a dropped connection, or no pending invitation (spec
/// 0010). Mirrors `SessionSyncException` (spec 0029).
///
/// Unlike the background profile upsert (which stays silent so it can never
/// break sign-in), these surface so the create/invite/accept UI (spec 0011) can
/// show an error.
class CompetitionSyncException implements Exception {
  /// Creates an exception wrapping the underlying [cause].
  const CompetitionSyncException(this.cause);

  /// The underlying error (e.g. a `PostgrestException`) or a message.
  final Object cause;

  @override
  String toString() => 'CompetitionSyncException: $cause';
}

/// The data seam for competitions, profiles, members and invitations (spec
/// 0010). The rest of the app depends on this interface, not a concrete backend
/// — mirroring `SessionRepository` — so the feature is testable with an
/// in-memory fake and never reaches a real Supabase.
abstract interface class CompetitionRepository {
  /// Upserts the signed-in user's own [profile] (called on sign-in).
  ///
  /// Best-effort and silent: a failure must never break sign-in, so it does not
  /// throw.
  Future<void> upsertOwnProfile(Profile profile);

  /// Creates [competition] (owned by the caller).
  ///
  /// The id is freshly generated per create, so this is a one-shot insert (not
  /// an upsert). Throws [CompetitionSyncException] on failure — the user is
  /// waiting on it.
  Future<void> createCompetition(Competition competition);

  /// The competitions the caller owns or is a member of, newest first.
  ///
  /// Throws [CompetitionSyncException] on a failed read.
  Future<List<Competition>> listMine();

  /// Invites [email] to the competition [competitionId] (owner only).
  ///
  /// Throws [CompetitionSyncException] on failure.
  Future<void> invite(String competitionId, String email);

  /// The caller's pending invitations, each with its competition attached.
  ///
  /// Throws [CompetitionSyncException] on a failed read.
  Future<List<CompetitionInvitation>> listMyInvitations();

  /// Accepts the invitation to [competitionId], joining the caller as a member.
  ///
  /// Throws [CompetitionSyncException] when there is no pending invitation for
  /// the caller, or on failure.
  Future<void> acceptInvitation(String competitionId);

  /// The participants of [competitionId], each with their profile when known.
  ///
  /// Throws [CompetitionSyncException] on a failed read.
  Future<List<CompetitionMember>> membersOf(String competitionId);

  /// Submits the caller's [result] to its competition (spec 0012).
  ///
  /// Idempotent by the session id: a re-submit is a no-op (the durable upload
  /// queue may retry). Throws [CompetitionSyncException] on failure — but the
  /// queue swallows it and retries on the next flush.
  Future<void> submitResult(CompetitionResult result);

  /// The submitted results for [competitionId] — the scoreboard — each with its
  /// submitter's profile, best first (highest [CompetitionResult.total], then
  /// most inner tens). Throws [CompetitionSyncException] on a failed read.
  Future<List<CompetitionResult>> resultsOf(String competitionId);
}

/// A [CompetitionRepository] that keeps everything in memory only.
///
/// The default binding and the test fake: it never touches the network. It is
/// scoped to a [currentUserId] / [currentEmail] so it can mirror the
/// owner/member/invitee visibility the real Row-Level Security enforces.
class InMemoryCompetitionRepository implements CompetitionRepository {
  /// Creates an in-memory repository acting as [currentUserId] / [currentEmail].
  InMemoryCompetitionRepository({this.currentUserId, this.currentEmail})
    : _profiles = <String, Profile>{},
      _competitions = <String, Competition>{},
      _members = <String, Set<String>>{},
      _invitations = <CompetitionInvitation>[],
      _results = <String, Map<String, CompetitionResult>>{};

  InMemoryCompetitionRepository._shared(
    this.currentUserId,
    this.currentEmail,
    this._profiles,
    this._competitions,
    this._members,
    this._invitations,
    this._results,
  );

  /// The acting user's id (owner/member checks), or `null` if signed out.
  final String? currentUserId;

  /// The acting user's email (invitation matching), or `null`.
  final String? currentEmail;

  final Map<String, Profile> _profiles;
  final Map<String, Competition> _competitions;
  final Map<String, Set<String>> _members;
  final List<CompetitionInvitation> _invitations;
  // competitionId -> (resultId -> result).
  final Map<String, Map<String, CompetitionResult>> _results;

  /// A view of the **same** store acting as a different user — for tests that
  /// drive a multi-user flow (one user invites, another accepts) against one
  /// shared backend.
  InMemoryCompetitionRepository asUser({String? userId, String? email}) =>
      InMemoryCompetitionRepository._shared(
        userId,
        email,
        _profiles,
        _competitions,
        _members,
        _invitations,
        _results,
      );

  String get _email => (currentEmail ?? '').toLowerCase();

  @override
  Future<void> upsertOwnProfile(Profile profile) async {
    _profiles[profile.id] = profile;
  }

  @override
  Future<void> createCompetition(Competition competition) async {
    _competitions[competition.id] = competition;
    // Mirror the owner-auto-membership trigger.
    (_members[competition.id] ??= <String>{}).add(competition.ownerId);
  }

  @override
  Future<List<Competition>> listMine() async {
    final uid = currentUserId;
    return _competitions.values
        .where(
          (c) => c.ownerId == uid || (_members[c.id]?.contains(uid) ?? false),
        )
        .toList();
  }

  @override
  Future<void> invite(String competitionId, String email) async {
    _invitations.add(
      CompetitionInvitation(
        competitionId: competitionId,
        invitedEmail: email.toLowerCase(),
        invitedBy: currentUserId,
      ),
    );
  }

  @override
  Future<List<CompetitionInvitation>> listMyInvitations() async {
    return _invitations
        .where((i) => i.invitedEmail == _email && i.status == 'pending')
        .map(
          (i) => CompetitionInvitation(
            competitionId: i.competitionId,
            invitedEmail: i.invitedEmail,
            invitedBy: i.invitedBy,
            status: i.status,
            createdAt: i.createdAt,
            competition: _competitions[i.competitionId],
          ),
        )
        .toList();
  }

  @override
  Future<void> acceptInvitation(String competitionId) async {
    final index = _invitations.indexWhere(
      (i) =>
          i.competitionId == competitionId &&
          i.invitedEmail == _email &&
          i.status == 'pending',
    );
    if (index < 0) {
      throw const CompetitionSyncException('no pending invitation');
    }
    final uid = currentUserId;
    if (uid != null) (_members[competitionId] ??= <String>{}).add(uid);
    final accepted = _invitations[index];
    _invitations[index] = CompetitionInvitation(
      competitionId: accepted.competitionId,
      invitedEmail: accepted.invitedEmail,
      invitedBy: accepted.invitedBy,
      status: 'accepted',
      createdAt: accepted.createdAt,
    );
  }

  @override
  Future<List<CompetitionMember>> membersOf(String competitionId) async {
    final ids = _members[competitionId] ?? const <String>{};
    return ids
        .map(
          (id) => CompetitionMember(
            competitionId: competitionId,
            userId: id,
            profile: _profiles[id],
          ),
        )
        .toList();
  }

  @override
  Future<void> submitResult(CompetitionResult result) async {
    final byId = _results.putIfAbsent(
      result.competitionId,
      () => <String, CompetitionResult>{},
    );
    // putIfAbsent mirrors the database's ON CONFLICT DO NOTHING: the first
    // submission of a session id wins, and a re-submit is a no-op. The userId
    // defaults to the acting user, as it does in the database.
    final stored = result.userId != null
        ? result
        : result.withUser(currentUserId);
    byId.putIfAbsent(result.id, () => stored);
  }

  @override
  Future<List<CompetitionResult>> resultsOf(String competitionId) async {
    final byId = _results[competitionId] ?? const <String, CompetitionResult>{};
    return byId.values.map((r) => r.withProfile(_profiles[r.userId])).toList()
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        return byTotal != 0 ? byTotal : b.innerTens.compareTo(a.innerTens);
      });
  }
}
