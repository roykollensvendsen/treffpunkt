// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

/// [CompetitionRepository] backed by Supabase (spec 0010).
///
/// Like `SupabaseSessionRepository`, this is excluded from automated tests (no
/// real credentials) and verified by the local-Supabase + `psql` RLS checklist
/// in spec 0010. Row-Level Security confines every read to the owner / members /
/// public, so the client filters are correctness, not security.
///
/// Error policy mirrors the sessions rules with one deliberate divergence: the
/// background [upsertOwnProfile] is **silent** (it must never break sign-in),
/// while [createCompetition] / [invite] / [acceptInvitation] are foreground
/// operations the user waits on, so they **throw** [CompetitionSyncException]
/// on failure (alongside the reads).
final class SupabaseCompetitionRepository implements CompetitionRepository {
  /// Creates a repository over the given Supabase client.
  SupabaseCompetitionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertOwnProfile(Profile profile) async {
    try {
      await _client.from('profiles').upsert(profile.toJson());
    } on Object catch (error) {
      // Best-effort: a missing table or dropped connection must not break
      // sign-in. Surface in debug only.
      if (!kReleaseMode) {
        debugPrint('Failed to upsert the profile: $error');
      }
    }
  }

  @override
  Future<void> createCompetition(Competition competition) async {
    try {
      // A plain insert, not an upsert: the id is freshly generated per create,
      // so there is nothing to merge — and an `upsert` issues
      // `ON CONFLICT DO UPDATE`, whose update path trips the owner-default
      // Row-Level Security check (`owner_id` defaults to `auth.uid()` and is
      // not sent), which a plain insert avoids.
      await _client.from('competitions').insert(competition.toInsertJson());
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<List<Competition>> listMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <Competition>[];
    try {
      // Inner-join membership filtered to me → competitions I own (owner is an
      // auto-member) or have joined; excludes public ones I have not joined.
      final rows = await _client
          .from('competitions')
          .select('*, competition_members!inner(user_id)')
          .eq('competition_members.user_id', uid)
          .order('created_at', ascending: false);
      return <Competition>[for (final row in rows) Competition.fromJson(row)];
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> invite(String competitionId, String email) async {
    try {
      await _client.from('competition_invitations').insert(<String, dynamic>{
        'competition_id': competitionId,
        'invited_email': email.toLowerCase(),
      });
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<List<CompetitionInvitation>> listMyInvitations() async {
    final email = _client.auth.currentUser?.email?.toLowerCase();
    if (email == null) return const <CompetitionInvitation>[];
    try {
      final rows = await _client
          .from('competition_invitations')
          .select('*, competitions(*)')
          .eq('invited_email', email)
          .eq('status', 'pending');
      return <CompetitionInvitation>[
        for (final row in rows) CompetitionInvitation.fromJson(row),
      ];
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> acceptInvitation(String competitionId) async {
    try {
      await _client.rpc<void>(
        'accept_invitation',
        params: <String, dynamic>{'cid': competitionId},
      );
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<List<CompetitionMember>> membersOf(String competitionId) async {
    try {
      final memberRows = await _client
          .from('competition_members')
          .select()
          .eq('competition_id', competitionId);
      final members = <CompetitionMember>[
        for (final row in memberRows) CompetitionMember.fromJson(row),
      ];
      if (members.isEmpty) return members;

      // There is no foreign key from members to profiles to embed, so read the
      // profiles for these users separately and attach them.
      final ids = members.map((m) => m.userId).toList();
      final profileRows = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids);
      final byId = <String, Profile>{
        for (final row in profileRows)
          row['id'] as String: Profile.fromJson(row),
      };
      return <CompetitionMember>[
        for (final m in members) m.withProfile(byId[m.userId]),
      ];
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> submitResult(CompetitionResult result) async {
    try {
      // Idempotent by id (the session id) via ON CONFLICT DO NOTHING, so a
      // queued retry is a server-side no-op. DO NOTHING (not DO UPDATE) runs
      // only the INSERT policy, so it is Row-Level-Security-safe — unlike an
      // upsert that updates, which would trip the user-default WITH CHECK.
      await _client
          .from('competition_results')
          .upsert(
            result.toInsertJson(),
            onConflict: 'id',
            ignoreDuplicates: true,
          );
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<List<CompetitionResult>> resultsOf(String competitionId) async {
    try {
      final rows = await _client
          .from('competition_results')
          .select()
          .eq('competition_id', competitionId)
          .order('total', ascending: false)
          .order('inner_tens', ascending: false);
      final results = <CompetitionResult>[
        for (final row in rows) CompetitionResult.fromJson(row),
      ];
      if (results.isEmpty) return results;

      // No foreign key from results to profiles to embed, so read the
      // submitters' profiles separately and attach them (like membersOf).
      final ids = results.map((r) => r.userId).whereType<String>().toList();
      final profileRows = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids);
      final byId = <String, Profile>{
        for (final row in profileRows)
          row['id'] as String: Profile.fromJson(row),
      };
      return <CompetitionResult>[
        for (final r in results) r.withProfile(byId[r.userId]),
      ];
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }
}
