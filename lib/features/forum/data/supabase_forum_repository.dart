// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';

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
    return <ForumThread>[
      for (final t in threads) t.withAuthorName(names[t.authorId]),
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
    return <ForumPost>[
      for (final p in posts) p.withAuthorName(names[p.authorId]),
    ];
  }

  Stream<T> _live<T>(
    String channel,
    String table,
    PostgresChangeFilter? filter,
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
        sub = _client
            .channel(channel)
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              filter: filter,
              callback: (_) => unawaited(emit()),
            )
            .subscribe();
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
  Stream<List<ForumThread>> watchThreads() =>
      _live('forum_threads', 'forum_threads', null, _threadsOf);

  @override
  Future<void> createThread(ForumThread thread) async {
    try {
      await _client.from('forum_threads').insert(thread.toInsertJson());
    } on Object catch (error) {
      throw ForumException(error);
    }
  }

  @override
  Future<void> deleteThread(String threadId) async {
    try {
      await _client.from('forum_threads').delete().eq('id', threadId);
    } on Object catch (error) {
      throw ForumException(error);
    }
  }

  @override
  Stream<List<ForumPost>> watchPosts(String threadId) => _live(
    'forum_posts:$threadId',
    'forum_posts',
    PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'thread_id',
      value: threadId,
    ),
    () => _postsOf(threadId),
  );

  @override
  Future<void> postReply(ForumPost post) async {
    try {
      await _client.from('forum_posts').insert(post.toInsertJson());
    } on Object catch (error) {
      throw ForumException(error);
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await _client.from('forum_posts').delete().eq('id', postId);
    } on Object catch (error) {
      throw ForumException(error);
    }
  }

  @override
  Future<bool> isAdmin() async {
    try {
      // RLS limits the select to the caller's own admin row, so a returned row
      // means they are a moderator.
      final row = await _client
          .from('app_admins')
          .select('user_id')
          .maybeSingle();
      return row != null;
    } on Object catch (error) {
      throw ForumException(error);
    }
  }
}
