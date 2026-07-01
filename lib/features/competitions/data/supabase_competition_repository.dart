// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/core/platform/image_format.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_message.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/message_reaction.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:uuid/uuid.dart';

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
  Future<Profile?> fetchProfile(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id, display_name, avatar_url')
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Profile.fromJson(row);
    } on Object catch (error) {
      // Best-effort: a read failure just means "no name yet", never a block.
      if (!kReleaseMode) {
        debugPrint('Failed to fetch the profile: $error');
      }
      return null;
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
  Future<void> deleteCompetition(String competitionId) async {
    try {
      // RLS ("Competitions are deletable by their owner") gates this; the
      // schema `on delete cascade` removes members, invitations and results.
      await _client.from('competitions').delete().eq('id', competitionId);
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<Set<String>> archivedCompetitionIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <String>{};
    try {
      // RLS confines the select to the caller's own archive rows.
      final rows = await _client
          .from('competition_archives')
          .select('competition_id');
      return <String>{
        for (final row in rows) row['competition_id'] as String,
      };
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> archiveCompetition(String competitionId) async {
    try {
      // Idempotent: DO NOTHING on the (competition_id, user_id) primary key, so
      // archiving twice is a no-op. user_id defaults to auth.uid() server-side.
      await _client
          .from('competition_archives')
          .upsert(
            <String, dynamic>{'competition_id': competitionId},
            onConflict: 'competition_id,user_id',
            ignoreDuplicates: true,
          );
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> unarchiveCompetition(String competitionId) async {
    try {
      // RLS scopes the delete to the caller's own row.
      await _client
          .from('competition_archives')
          .delete()
          .eq('competition_id', competitionId);
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
  Future<List<Profile>> listShooters() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name, avatar_url')
          .order('display_name');
      return <Profile>[for (final row in rows) Profile.fromJson(row)];
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> inviteUser(String competitionId, String userId) async {
    try {
      // The RPC resolves the shooter's email server-side and writes the
      // email-keyed invitation; the email never reaches this client.
      await _client.rpc<void>(
        'invite_user_to_competition',
        params: <String, dynamic>{
          'cid': competitionId,
          'target_user_id': userId,
        },
      );
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
  Future<List<String>> pendingInviteeIds(String competitionId) async {
    try {
      // The RPC resolves email-keyed invitations to user ids server-side and
      // enforces owner-only; a non-owner gets an empty set.
      final rows = await _client.rpc<List<dynamic>>(
        'pending_invitee_ids',
        params: <String, dynamic>{'cid': competitionId},
      );
      return <String>[
        for (final row in rows)
          (row as Map<String, dynamic>)['user_id'] as String,
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
  Future<String?> joinToken(String competitionId) async {
    try {
      // RLS limits the select to the owner's row, so a non-owner reads null.
      final row = await _client
          .from('competition_join_tokens')
          .select('token')
          .eq('competition_id', competitionId)
          .maybeSingle();
      return row?['token'] as String?;
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> joinByLink(String competitionId, String token) async {
    try {
      await _client.rpc<void>(
        'join_competition',
        params: <String, dynamic>{'cid': competitionId, 'join_token': token},
      );
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<String> regenerateJoinToken(String competitionId) async {
    try {
      final token = await _client.rpc<String>(
        'regenerate_join_token',
        params: <String, dynamic>{'cid': competitionId},
      );
      return token;
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

  @override
  Stream<List<CompetitionResult>> watchResults(String competitionId) {
    final controller = StreamController<List<CompetitionResult>>();
    RealtimeChannel? channel;

    Future<void> emit() async {
      try {
        if (!controller.isClosed) {
          controller.add(await resultsOf(competitionId));
        }
      } on Object catch (error) {
        if (!controller.isClosed) {
          controller.addError(CompetitionSyncException(error));
        }
      }
    }

    controller
      ..onListen = () {
        // Subscribe to inserts/updates/deletes for this competition's results;
        // Row-Level Security limits delivery to rows the user may read. On any
        // change (and on the initial subscribe) re-read the full scoreboard.
        channel = _client
            .channel('competition_results:$competitionId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'competition_results',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'competition_id',
                value: competitionId,
              ),
              callback: (_) => unawaited(emit()),
            )
            .subscribe();
        unawaited(emit());
      }
      ..onCancel = () async {
        final open = channel;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      };
    return controller.stream;
  }

  @override
  Future<void> postMessage(CompetitionMessage message) async {
    try {
      await _client.from('competition_messages').insert(message.toInsertJson());
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  /// Maps the given user ids to display names from `profiles` (spec 0059).
  Future<Map<String, String>> _displayNamesFor(
    Iterable<String?> userIds,
  ) async {
    final ids = userIds.whereType<String>().toSet().toList();
    if (ids.isEmpty) return const <String, String>{};
    final rows = await _client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', ids);
    return <String, String>{
      for (final row in rows)
        if (row['display_name'] != null)
          row['id'] as String: row['display_name'] as String,
    };
  }

  /// Reads a competition's chat (oldest first) with the authors' profiles
  /// attached — there is no foreign key from messages to profiles to embed, so
  /// the profiles are read separately, like [resultsOf] / [membersOf].
  Future<List<CompetitionMessage>> _messagesOf(String competitionId) async {
    final rows = await _client
        .from('competition_messages')
        .select()
        .eq('competition_id', competitionId)
        .order('created_at', ascending: true);
    final messages = <CompetitionMessage>[
      for (final row in rows) CompetitionMessage.fromJson(row),
    ];
    if (messages.isEmpty) return messages;
    final ids = messages.map((m) => m.userId).whereType<String>().toList();
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('id', ids);
    final byId = <String, Profile>{
      for (final row in profileRows) row['id'] as String: Profile.fromJson(row),
    };
    // Reactions for these messages (spec 0052), grouped by message id, each
    // with the reactor's name attached for the "who reacted" list (spec 0059).
    final messageIds = messages.map((m) => m.id).toList();
    final reactionRows = await _client
        .from('competition_message_reactions')
        .select()
        .inFilter('message_id', messageIds)
        .order('created_at', ascending: true);
    final reactionNames = await _displayNamesFor(
      reactionRows.map((r) => r['user_id'] as String?),
    );
    final reactionsByMessage = <String, List<MessageReaction>>{};
    for (final row in reactionRows) {
      final reaction = MessageReaction.fromJson(row);
      (reactionsByMessage[reaction.messageId] ??= <MessageReaction>[]).add(
        reaction.withUserName(reactionNames[reaction.userId]),
      );
    }
    // Signed URLs for any attached images (the bucket is private, spec 0053).
    final imagePaths = messages
        .map((m) => m.imagePath)
        .whereType<String>()
        .toSet();
    final signedByPath = <String, String>{};
    for (final path in imagePaths) {
      try {
        signedByPath[path] = await _client.storage
            .from('chat-images')
            .createSignedUrl(path, 3600);
      } on Object {
        // A missing or unreadable object just renders no image.
      }
    }
    return <CompetitionMessage>[
      for (final m in messages)
        m
            .withProfile(byId[m.userId])
            .withReactions(
              reactionsByMessage[m.id] ?? const <MessageReaction>[],
            )
            .withImageUrl(
              m.imagePath == null ? null : signedByPath[m.imagePath],
            ),
    ];
  }

  @override
  Stream<List<CompetitionMessage>> watchMessages(String competitionId) {
    final controller = StreamController<List<CompetitionMessage>>();
    RealtimeChannel? channel;

    Future<void> emit() async {
      try {
        if (!controller.isClosed) {
          controller.add(await _messagesOf(competitionId));
        }
      } on Object catch (error) {
        if (!controller.isClosed) {
          controller.addError(CompetitionSyncException(error));
        }
      }
    }

    controller
      ..onListen = () {
        // Inserts/deletes for this competition's chat; RLS limits delivery to
        // rows the user may read. Re-read the chat on any change (and on the
        // initial subscribe).
        channel = _client
            .channel('competition_messages:$competitionId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'competition_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'competition_id',
                value: competitionId,
              ),
              callback: (_) => unawaited(emit()),
            )
            // Reactions have no competition_id to filter on, so listen to all
            // reaction changes — RLS still limits delivery to readable rows —
            // and re-read the chat (spec 0052).
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'competition_message_reactions',
              callback: (_) => unawaited(emit()),
            )
            .subscribe();
        unawaited(emit());
      }
      ..onCancel = () async {
        final open = channel;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      };
    return controller.stream;
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      // RLS allows the author or the competition owner; for anyone else the
      // delete matches no row (a no-op).
      await _client.from('competition_messages').delete().eq('id', messageId);
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> editMessage(String messageId, {required String body}) async {
    try {
      // RLS limits the update to the author's own message (spec 0070).
      await _client
          .from('competition_messages')
          .update(<String, dynamic>{'body': body})
          .eq('id', messageId);
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      // Toggle: delete the caller's own reaction with this emoji (RLS limits
      // the delete to it); if there was none, insert it. user_id defaults to
      // auth.uid() on insert (spec 0052).
      final removed = await _client
          .from('competition_message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('emoji', emoji)
          .select();
      if ((removed as List<dynamic>).isEmpty) {
        await _client.from('competition_message_reactions').insert(
          <String, dynamic>{'message_id': messageId, 'emoji': emoji},
        );
      }
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }

  @override
  Future<String> uploadChatImage(
    String competitionId,
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) async {
    try {
      // Path's first segment is the competition id — Storage RLS reads it to
      // gate the upload to a participant (spec 0053).
      final path = '$competitionId/${const Uuid().v4()}.$fileExtension';
      final contentType = imageMimeForExtension(fileExtension);
      await _client.storage
          .from('chat-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      return path;
    } on Object catch (error) {
      throw CompetitionSyncException(error);
    }
  }
}
