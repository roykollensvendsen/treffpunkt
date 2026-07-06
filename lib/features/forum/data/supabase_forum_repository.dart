// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/core/platform/image_format.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_reaction.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';
import 'package:uuid/uuid.dart';

/// [ForumRepository] backed by Supabase (spec 0054).
///
/// Like the other Supabase repositories, it is excluded from automated tests
/// (no real credentials); Row-Level Security confines reads/writes, so the
/// client logic is correctness, not security. Mirrors the competition chat's
/// Realtime + profile-attach pattern.
final class SupabaseForumRepository implements ForumRepository {
  /// Creates a repository over the given Supabase client.
  SupabaseForumRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, String>> _namesFor(Iterable<String?> authorIds) async {
    final ids = authorIds.whereType<String>().toSet().toList();
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

  Future<Map<String, List<ForumReaction>>> _reactionsByTarget(
    String targetType,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <String, List<ForumReaction>>{};
    final rows = await _client
        .from('forum_reactions')
        .select('target_id, user_id, emoji')
        .eq('target_type', targetType)
        .inFilter('target_id', ids)
        .order('created_at', ascending: true);
    // Attach each reactor's name for the "who reacted" list (spec 0059).
    final names = await _namesFor(rows.map((r) => r['user_id'] as String?));
    final byTarget = <String, List<ForumReaction>>{};
    for (final row in rows) {
      final reaction = ForumReaction.fromJson(row);
      (byTarget[row['target_id'] as String] ??= <ForumReaction>[]).add(
        reaction.withUserName(names[reaction.userId]),
      );
    }
    return byTarget;
  }

  /// Signed URLs for the given object paths in the private `forum-images`
  /// bucket (spec 0056); a missing/unreadable path is simply skipped.
  Future<Map<String, String>> _signedUrls(Iterable<String?> paths) async {
    final unique = paths.whereType<String>().toSet();
    final byPath = <String, String>{};
    for (final path in unique) {
      try {
        byPath[path] = await _client.storage
            .from('forum-images')
            .createSignedUrl(path, 3600);
      } on Object {
        // Skip a missing image.
      }
    }
    return byPath;
  }

  Future<List<ForumThread>> _threadsOf() async {
    final rows = await _client
        .from('forum_threads')
        .select()
        .order('created_at', ascending: false);
    final threads = <ForumThread>[
      for (final row in rows) ForumThread.fromJson(row),
    ];
    if (threads.isEmpty) return threads;
    final names = await _namesFor(threads.map((t) => t.authorId));
    final reactions = await _reactionsByTarget(
      'thread',
      threads.map((t) => t.id).toList(),
    );
    final urls = await _signedUrls(threads.map((t) => t.imagePath));
    return <ForumThread>[
      for (final t in threads)
        t
            .withAuthorName(names[t.authorId])
            .withReactions(reactions[t.id] ?? const <ForumReaction>[])
            .withImageUrl(t.imagePath == null ? null : urls[t.imagePath]),
    ];
  }

  Future<List<ForumPost>> _postsOf(String threadId) async {
    final rows = await _client
        .from('forum_posts')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);
    final posts = <ForumPost>[for (final row in rows) ForumPost.fromJson(row)];
    if (posts.isEmpty) return posts;
    final names = await _namesFor(posts.map((p) => p.authorId));
    final reactions = await _reactionsByTarget(
      'post',
      posts.map((p) => p.id).toList(),
    );
    final urls = await _signedUrls(posts.map((p) => p.imagePath));
    return <ForumPost>[
      for (final p in posts)
        p
            .withAuthorName(names[p.authorId])
            .withReactions(reactions[p.id] ?? const <ForumReaction>[])
            .withImageUrl(p.imagePath == null ? null : urls[p.imagePath]),
    ];
  }

  Stream<T> _live<T>(
    String channel,
    List<({String table, PostgresChangeFilter? filter})> tables,
    Future<T> Function() read,
  ) {
    final controller = StreamController<T>();
    RealtimeChannel? sub;

    Future<void> emit() async {
      try {
        if (!controller.isClosed) controller.add(await read());
      } on Object catch (error) {
        if (!controller.isClosed) controller.addError(ForumException(error));
      }
    }

    controller
      ..onListen = () {
        var channelBuilder = _client.channel(channel);
        for (final t in tables) {
          channelBuilder = channelBuilder.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: t.table,
            filter: t.filter,
            callback: (_) => unawaited(emit()),
          );
        }
        sub = channelBuilder.subscribe();
        unawaited(emit());
      }
      ..onCancel = () async {
        final open = sub;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      };
    return controller.stream;
  }

  @override
  Stream<List<ForumThread>> watchThreads() => _live(
    'forum_threads',
    const [
      (table: 'forum_threads', filter: null),
      // Reactions have no thread filter, so re-read on any reaction change;
      // RLS still applies (spec 0055).
      (table: 'forum_reactions', filter: null),
    ],
    _threadsOf,
  );

  @override
  Future<void> createThread(ForumThread thread) => guardSync(
    () async {
      await _client.from('forum_threads').insert(thread.toInsertJson());
    },
    debugLabel: 'Failed to create the thread',
    wrap: ForumException.new,
  );

  @override
  Future<void> deleteThread(String threadId) => guardSync(
    () async {
      await _client.from('forum_threads').delete().eq('id', threadId);
    },
    debugLabel: 'Failed to delete the thread',
    wrap: ForumException.new,
  );

  @override
  Stream<List<ForumPost>> watchPosts(String threadId) => _live(
    'forum_posts:$threadId',
    [
      (
        table: 'forum_posts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'thread_id',
          value: threadId,
        ),
      ),
      (table: 'forum_reactions', filter: null),
    ],
    () => _postsOf(threadId),
  );

  @override
  Future<void> postReply(ForumPost post) => guardSync(
    () async {
      await _client.from('forum_posts').insert(post.toInsertJson());
    },
    debugLabel: 'Failed to post the reply',
    wrap: ForumException.new,
  );

  @override
  Future<void> deletePost(String postId) => guardSync(
    () async {
      await _client.from('forum_posts').delete().eq('id', postId);
    },
    debugLabel: 'Failed to delete the post',
    wrap: ForumException.new,
  );

  @override
  Future<void> editThread(
    String threadId, {
    required String title,
    required String body,
  }) => guardSync(
    () async {
      // RLS limits the update to the author's own thread (spec 0063).
      await _client
          .from('forum_threads')
          .update(<String, dynamic>{'title': title, 'body': body})
          .eq('id', threadId);
    },
    debugLabel: 'Failed to edit the thread',
    wrap: ForumException.new,
  );

  @override
  Future<void> editPost(String postId, {required String body}) => guardSync(
    () async {
      await _client
          .from('forum_posts')
          .update(<String, dynamic>{'body': body})
          .eq('id', postId);
    },
    debugLabel: 'Failed to edit the post',
    wrap: ForumException.new,
  );

  @override
  Future<void> setThreadStatus(
    String threadId,
    ForumThreadStatus status,
  ) => guardSync(
    () async {
      // The RPC checks is_app_admin and updates only the status column
      // (spec 0066).
      await _client.rpc<void>(
        'set_thread_status',
        params: <String, dynamic>{
          'p_thread_id': threadId,
          'p_status': status.wire,
        },
      );
    },
    debugLabel: 'Failed to set the thread status',
    wrap: ForumException.new,
  );

  @override
  Future<bool> isAdmin() => guardSync(
    () async {
      // RLS limits the select to the caller's own admin row, so a returned row
      // means they are a moderator.
      final row = await _client
          .from('app_admins')
          .select('user_id')
          .maybeSingle();
      return row != null;
    },
    debugLabel: 'Failed to check moderator status',
    wrap: ForumException.new,
  );

  @override
  Future<void> toggleReaction({
    required String targetType,
    required String targetId,
    required String emoji,
  }) => guardSync(
    () async {
      // Toggle: delete the caller's own reaction (RLS limits the delete to it);
      // if there was none, insert it (spec 0055).
      final removed = await _client
          .from('forum_reactions')
          .delete()
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .eq('emoji', emoji)
          .select();
      if ((removed as List<dynamic>).isEmpty) {
        await _client.from('forum_reactions').insert(<String, dynamic>{
          'target_type': targetType,
          'target_id': targetId,
          'emoji': emoji,
        });
      }
    },
    debugLabel: 'Failed to toggle the reaction',
    wrap: ForumException.new,
  );

  @override
  Future<String> uploadForumImage(
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) => guardSync(
    () async {
      final path = '${const Uuid().v4()}.$fileExtension';
      final contentType = imageMimeForExtension(fileExtension);
      await _client.storage
          .from('forum-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      return path;
    },
    debugLabel: 'Failed to upload the forum image',
    wrap: ForumException.new,
  );

  @override
  Future<DateTime?> robotSeenAt() async {
    try {
      final row = await _client
          .from('robot_presence')
          .select('seen_at')
          .maybeSingle();
      return parseWireTimeOrNull(row?['seen_at'] as String?);
    } on Object {
      // Presence is decoration (spec 0122): unreachable reads as absent.
      return null;
    }
  }
}
