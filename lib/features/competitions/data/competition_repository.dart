// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

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

  /// Deletes the competition [competitionId] (owner only, spec 0034).
  ///
  /// Cascades to its members, invitations and results (the database `on delete
  /// cascade`). Throws [CompetitionSyncException] on failure — the user is
  /// waiting on it; Row-Level Security rejects a non-owner.
  Future<void> deleteCompetition(String competitionId);

  /// Invites [email] to the competition [competitionId] (owner only).
  ///
  /// Throws [CompetitionSyncException] on failure.
  Future<void> invite(String competitionId, String email);

  /// The registered shooters, for the invite picker (spec 0032).
  ///
  /// Profiles hold only a name and avatar — never an email — so the picker can
  /// show who is who without exposing addresses. Throws
  /// [CompetitionSyncException] on a failed read.
  Future<List<Profile>> listShooters();

  /// Invites the registered shooter [userId] to [competitionId] (owner only).
  ///
  /// The shooter's email is resolved server-side (never reaches the client) and
  /// reused as the email-keyed invitation, so the accept flow is unchanged.
  /// Idempotent. Throws [CompetitionSyncException] on failure.
  Future<void> inviteUser(String competitionId, String userId);

  /// The caller's pending invitations, each with its competition attached.
  ///
  /// Throws [CompetitionSyncException] on a failed read.
  Future<List<CompetitionInvitation>> listMyInvitations();

  /// The user ids of [competitionId]'s registered shooters with a pending
  /// invitation — so the owner's invite picker can mark them already invited.
  ///
  /// Owner-only: a non-owner gets an empty list. Resolves the email-keyed
  /// invitations to user ids server-side, so no email reaches the client
  /// (spec 0032). Throws [CompetitionSyncException] on a failed read.
  Future<List<String>> pendingInviteeIds(String competitionId);

  /// Accepts the invitation to [competitionId], joining the caller as a member.
  ///
  /// Throws [CompetitionSyncException] when there is no pending invitation for
  /// the caller, or on failure.
  Future<void> acceptInvitation(String competitionId);

  /// The competition's current join token, for building a shareable link
  /// (spec 0048). **Owner-only**: a non-owner read returns `null`. Throws
  /// [CompetitionSyncException] on a failed read.
  Future<String?> joinToken(String competitionId);

  /// Joins the caller to [competitionId] using a shared-link [token]
  /// (idempotent). Throws [CompetitionSyncException] on a bad/expired token or
  /// on failure.
  Future<void> joinByLink(String competitionId, String token);

  /// Regenerates [competitionId]'s join token (owner only), invalidating old
  /// links, and returns the new token. Throws [CompetitionSyncException] on
  /// failure.
  Future<String> regenerateJoinToken(String competitionId);

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

  /// A live stream of [competitionId]'s results (spec 0013): it emits the
  /// current scoreboard immediately, then re-emits whenever a result is
  /// submitted, so the detail screen updates without reopening. The real
  /// backend is driven by Supabase Realtime; each emission is the full re-read
  /// of [resultsOf].
  Stream<List<CompetitionResult>> watchResults(String competitionId);
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
      _emailByUserId = <String, String>{},
      _competitions = <String, Competition>{},
      _members = <String, Set<String>>{},
      _invitations = <CompetitionInvitation>[],
      _joinTokens = <String, String>{},
      _tokenSeq = <int>[0],
      _results = <String, Map<String, CompetitionResult>>{},
      _resultsChanged = StreamController<String>.broadcast();

  InMemoryCompetitionRepository._shared(
    this.currentUserId,
    this.currentEmail,
    this._profiles,
    this._emailByUserId,
    this._competitions,
    this._members,
    this._invitations,
    this._joinTokens,
    this._tokenSeq,
    this._results,
    this._resultsChanged,
  );

  /// The acting user's id (owner/member checks), or `null` if signed out.
  final String? currentUserId;

  /// The acting user's email (invitation matching), or `null`.
  final String? currentEmail;

  final Map<String, Profile> _profiles;
  // The server-side userId -> email map the real backend reads from auth.users.
  // Populated when a user syncs their own profile (the only time we know both).
  final Map<String, String> _emailByUserId;
  final Map<String, Competition> _competitions;
  final Map<String, Set<String>> _members;
  final List<CompetitionInvitation> _invitations;
  // competitionId -> current join token (spec 0048); created with the
  // competition, owner-only on read, replaced by regenerate.
  final Map<String, String> _joinTokens;
  // A shared one-element counter so regenerated tokens differ; a list so the
  // asUser() views share the same mutable holder.
  final List<int> _tokenSeq;
  // competitionId -> (resultId -> result).
  final Map<String, Map<String, CompetitionResult>> _results;
  // Emits a competitionId whenever a new result lands there, so watchResults
  // re-reads the scoreboard (the in-memory stand-in for Supabase Realtime).
  final StreamController<String> _resultsChanged;

  /// A view of the **same** store acting as a different user — for tests that
  /// drive a multi-user flow (one user invites, another accepts) against one
  /// shared backend.
  InMemoryCompetitionRepository asUser({String? userId, String? email}) =>
      InMemoryCompetitionRepository._shared(
        userId,
        email,
        _profiles,
        _emailByUserId,
        _competitions,
        _members,
        _invitations,
        _joinTokens,
        _tokenSeq,
        _results,
        _resultsChanged,
      );

  String get _email => (currentEmail ?? '').toLowerCase();

  @override
  Future<void> upsertOwnProfile(Profile profile) async {
    _profiles[profile.id] = profile;
    // Mirror the server knowing the user's email (from auth.users) when they
    // sync their own profile — the only moment we hold both id and email.
    final email = currentEmail;
    if (currentUserId == profile.id && email != null) {
      _emailByUserId[profile.id] = email;
    }
  }

  @override
  Future<void> createCompetition(Competition competition) async {
    _competitions[competition.id] = competition;
    // Mirror the owner-auto-membership trigger.
    (_members[competition.id] ??= <String>{}).add(competition.ownerId);
    // Mirror the add_join_token trigger (spec 0048).
    _joinTokens[competition.id] ??= _newToken();
  }

  String _newToken() => 'jointoken-${_tokenSeq[0]++}';

  @override
  Future<void> deleteCompetition(String competitionId) async {
    // Mirror the database cascade: drop the competition and everything that
    // references it (members, invitations, results).
    _competitions.remove(competitionId);
    _members.remove(competitionId);
    _results.remove(competitionId);
    _invitations.removeWhere((i) => i.competitionId == competitionId);
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
  Future<List<Profile>> listShooters() async =>
      _profiles.values.toList(growable: false);

  @override
  Future<void> inviteUser(String competitionId, String userId) async {
    final email = _emailByUserId[userId];
    if (email == null) {
      throw const CompetitionSyncException(
        'unknown user, or user has no email',
      );
    }
    await invite(competitionId, email);
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
  Future<List<String>> pendingInviteeIds(String competitionId) async {
    // Owner-only, mirroring the RPC's owner gate.
    final competition = _competitions[competitionId];
    if (competition == null || competition.ownerId != currentUserId) {
      return const <String>[];
    }
    final pendingEmails = _invitations
        .where(
          (i) => i.competitionId == competitionId && i.status == 'pending',
        )
        .map((i) => i.invitedEmail)
        .toSet();
    // Resolve the email-keyed invitations back to the registered user ids.
    return <String>[
      for (final entry in _emailByUserId.entries)
        if (pendingEmails.contains(entry.value.toLowerCase())) entry.key,
    ];
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
  Future<String?> joinToken(String competitionId) async {
    // Owner-only read, mirroring the RLS select policy.
    final competition = _competitions[competitionId];
    if (competition == null || competition.ownerId != currentUserId) {
      return null;
    }
    return _joinTokens[competitionId];
  }

  @override
  Future<void> joinByLink(String competitionId, String token) async {
    if (_joinTokens[competitionId] != token) {
      throw const CompetitionSyncException('invalid or expired join link');
    }
    final uid = currentUserId;
    if (uid != null) (_members[competitionId] ??= <String>{}).add(uid);
  }

  @override
  Future<String> regenerateJoinToken(String competitionId) async {
    final competition = _competitions[competitionId];
    if (competition == null || competition.ownerId != currentUserId) {
      throw const CompetitionSyncException('only the owner may regenerate');
    }
    return _joinTokens[competitionId] = _newToken();
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
    // ON CONFLICT DO NOTHING: the first submission of a session id wins, a
    // re-submit is a no-op (and emits nothing).
    if (byId.containsKey(result.id)) return;
    // The userId defaults to the acting user, as it does in the database.
    byId[result.id] = result.userId != null
        ? result
        : result.withUser(currentUserId);
    // Signal watchers of this competition (the Realtime stand-in).
    if (_resultsChanged.hasListener) _resultsChanged.add(result.competitionId);
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

  @override
  Stream<List<CompetitionResult>> watchResults(String competitionId) async* {
    yield await resultsOf(competitionId);
    await for (final changed in _resultsChanged.stream) {
      if (changed == competitionId) yield await resultsOf(competitionId);
    }
  }
}
