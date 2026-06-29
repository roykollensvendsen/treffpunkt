// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_reaction.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';

/// Thrown when a forum read or a write the user is waiting on fails
/// (spec 0054). Mirrors `CompetitionSyncException`.
class ForumException implements Exception {
  /// Creates an exception wrapping [cause].
  const ForumException(this.cause);

  /// The underlying error or a message.
  final Object cause;

  @override
  String toString() => 'ForumException: $cause';
}

/// The data seam for the community forum (spec 0054): threads, their replies,
/// and whether the viewer is a moderator. The app depends on this interface, so
/// it is testable with an in-memory fake and never reaches a real Supabase.
abstract interface class ForumRepository {
  /// A live stream of all threads, newest first, each with its author's name.
  Stream<List<ForumThread>> watchThreads();

  /// Creates [thread] (authored by the caller). Throws [ForumException].
  Future<void> createThread(ForumThread thread);

  /// Deletes thread [threadId] (author or admin); cascades to its replies.
  /// Throws [ForumException].
  Future<void> deleteThread(String threadId);

  /// A live stream of thread [threadId]'s replies, oldest first, each with its
  /// author's name.
  Stream<List<ForumPost>> watchPosts(String threadId);

  /// Posts [post] as a reply (authored by the caller). Throws [ForumException].
  Future<void> postReply(ForumPost post);

  /// Deletes reply [postId] (author or admin). Throws [ForumException].
  Future<void> deletePost(String postId);

  /// Whether the caller is a moderator (may delete others' threads/replies).
  Future<bool> isAdmin();

  /// Toggles the caller's [emoji] reaction on a forum [targetType] (`thread` or
  /// `post`) identified by [targetId] (spec 0055): adds it when absent, removes
  /// it when present. Delivered live through [watchThreads] / [watchPosts].
  Future<void> toggleReaction({
    required String targetType,
    required String targetId,
    required String emoji,
  });
}

/// A [ForumRepository] kept entirely in memory — the default binding and the
/// test fake. Scoped to a [currentUserId]; a shared store via [asUser] lets a
/// cross-user test drive a multi-person forum against one backend.
class InMemoryForumRepository implements ForumRepository {
  /// Creates an in-memory forum acting as [currentUserId].
  InMemoryForumRepository({this.currentUserId})
    : _threads = <String, ForumThread>{},
      _posts = <String, ForumPost>{},
      _names = <String, String>{},
      _admins = <String>{},
      _reactions = <String, List<ForumReaction>>{},
      _seq = <int>[0],
      _changed = StreamController<void>.broadcast();

  InMemoryForumRepository._shared(
    this.currentUserId,
    this._threads,
    this._posts,
    this._names,
    this._admins,
    this._reactions,
    this._seq,
    this._changed,
  );

  /// The acting user's id, or `null` when signed out.
  final String? currentUserId;

  final Map<String, ForumThread> _threads;
  final Map<String, ForumPost> _posts;
  final Map<String, String> _names; // userId -> display name
  final Set<String> _admins; // moderator user ids
  // '<type>:<id>' -> reactions, in insertion order (spec 0055).
  final Map<String, List<ForumReaction>> _reactions;
  final List<int> _seq; // monotonic createdAt stamp
  final StreamController<void> _changed;

  /// A view of the same store acting as a different user.
  InMemoryForumRepository asUser({String? userId}) =>
      InMemoryForumRepository._shared(
        userId,
        _threads,
        _posts,
        _names,
        _admins,
        _reactions,
        _seq,
        _changed,
      );

  /// Seeds a user's display name (mirrors the `profiles` the real backend
  /// reads), so threads/replies show a name.
  void setDisplayName(String userId, String name) => _names[userId] = name;

  /// Marks [userId] a moderator (mirrors an `app_admins` row).
  void addAdmin(String userId) => _admins.add(userId);

  DateTime _stamp() => DateTime.fromMillisecondsSinceEpoch(_seq[0]++);

  void _emit() {
    if (_changed.hasListener) _changed.add(null);
  }

  List<ForumReaction> _reactionsFor(String type, String id) =>
      List<ForumReaction>.unmodifiable(
        _reactions['$type:$id'] ?? const <ForumReaction>[],
      );

  List<ForumThread> _threadList() {
    final list =
        _threads.values
            .map(
              (t) => t
                  .withAuthorName(_names[t.authorId])
                  .withReactions(_reactionsFor('thread', t.id)),
            )
            .toList()
          ..sort((a, b) {
            final at = a.createdAt ?? DateTime(0);
            final bt = b.createdAt ?? DateTime(0);
            return bt.compareTo(at); // newest first
          });
    return list;
  }

  List<ForumPost> _postsOf(String threadId) {
    return _posts.values
        .where((p) => p.threadId == threadId)
        .map(
          (p) => p
              .withAuthorName(_names[p.authorId])
              .withReactions(_reactionsFor('post', p.id)),
        )
        .toList()
      ..sort((a, b) {
        final at = a.createdAt ?? DateTime(0);
        final bt = b.createdAt ?? DateTime(0);
        return at.compareTo(bt); // oldest first
      });
  }

  @override
  Stream<List<ForumThread>> watchThreads() async* {
    yield _threadList();
    await for (final _ in _changed.stream) {
      yield _threadList();
    }
  }

  @override
  Future<void> createThread(ForumThread thread) async {
    _threads[thread.id] = ForumThread(
      id: thread.id,
      category: thread.category,
      title: thread.title,
      body: thread.body,
      authorId: thread.authorId ?? currentUserId,
      createdAt: _stamp(),
    );
    _emit();
  }

  @override
  Future<void> deleteThread(String threadId) async {
    final thread = _threads[threadId];
    if (thread == null) return;
    if (thread.authorId == currentUserId || _isAdmin) {
      _threads.remove(threadId);
      _posts.removeWhere((_, p) => p.threadId == threadId);
      _emit();
    }
  }

  @override
  Stream<List<ForumPost>> watchPosts(String threadId) async* {
    yield _postsOf(threadId);
    await for (final _ in _changed.stream) {
      yield _postsOf(threadId);
    }
  }

  @override
  Future<void> postReply(ForumPost post) async {
    _posts[post.id] = ForumPost(
      id: post.id,
      threadId: post.threadId,
      body: post.body,
      authorId: post.authorId ?? currentUserId,
      createdAt: _stamp(),
    );
    _emit();
  }

  @override
  Future<void> deletePost(String postId) async {
    final post = _posts[postId];
    if (post == null) return;
    if (post.authorId == currentUserId || _isAdmin) {
      _posts.remove(postId);
      _emit();
    }
  }

  @override
  Future<bool> isAdmin() async => _isAdmin;

  @override
  Future<void> toggleReaction({
    required String targetType,
    required String targetId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    final list = _reactions.putIfAbsent(
      '$targetType:$targetId',
      () => <ForumReaction>[],
    );
    final mine = ForumReaction(userId: uid, emoji: emoji);
    if (!list.remove(mine)) list.add(mine);
    _emit();
  }

  bool get _isAdmin => currentUserId != null && _admins.contains(currentUserId);
}
