// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the in-memory forum repository (spec 0054): threads list newest
// first with author names; replies stream oldest first; the author deletes
// their own, an admin moderates anyone's, others cannot; isAdmin reflects the
// admin set. The cross-user flow uses one shared store via asUser().
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';

ForumThread _thread(
  String id, {
  ForumCategory category = ForumCategory.bug,
  String title = 'Tittel',
  String? authorId,
}) => ForumThread(
  id: id,
  category: category,
  title: title,
  authorId: authorId,
);

ForumPost _post(String id, String threadId, String body, {String? authorId}) =>
    ForumPost(id: id, threadId: threadId, body: body, authorId: authorId);

void main() {
  test('threads are listed newest first with author names', () async {
    final alice = InMemoryForumRepository(currentUserId: 'alice')
      ..setDisplayName('alice', 'Alice');
    await alice.createThread(_thread('t1', title: 'First'));
    await alice.createThread(_thread('t2', title: 'Second'));

    final list = await alice.watchThreads().first;
    expect(list.map((t) => t.id), <String>['t2', 't1']); // newest first
    expect(list.first.authorId, 'alice');
    expect(list.first.authorName, 'Alice');
  });

  test('replies stream oldest first and carry author names', () async {
    final alice = InMemoryForumRepository(currentUserId: 'alice')
      ..setDisplayName('alice', 'Alice')
      ..setDisplayName('bob', 'Bob');
    final bob = alice.asUser(userId: 'bob');
    await alice.createThread(_thread('t1'));
    await alice.postReply(_post('p1', 't1', 'hei'));
    await bob.postReply(_post('p2', 't1', 'hallo'));

    final posts = await alice.watchPosts('t1').first;
    expect(posts.map((p) => p.body), <String>['hei', 'hallo']);
    expect(posts.map((p) => p.authorName), <String>['Alice', 'Bob']);
  });

  test('the author deletes own; an admin moderates; others cannot', () async {
    final alice = InMemoryForumRepository(currentUserId: 'alice');
    final bob = alice.asUser(userId: 'bob');
    final mod = alice.asUser(userId: 'mod');
    alice.addAdmin('mod');
    await bob.createThread(_thread('t1', authorId: 'bob'));
    await bob.postReply(_post('p1', 't1', 'bob-svar', authorId: 'bob'));

    // Alice — neither author nor admin — cannot delete Bob's reply (no-op).
    await alice.deletePost('p1');
    expect(await alice.watchPosts('t1').first, hasLength(1));

    // The moderator deletes the reply, then the whole thread.
    await mod.deletePost('p1');
    expect(await alice.watchPosts('t1').first, isEmpty);
    await mod.deleteThread('t1');
    expect(await alice.watchThreads().first, isEmpty);
  });

  test('isAdmin reflects the admin set', () async {
    final alice = InMemoryForumRepository(currentUserId: 'alice');
    expect(await alice.isAdmin(), isFalse);
    alice.addAdmin('alice');
    expect(await alice.isAdmin(), isTrue);
  });

  test(
    'reactions toggle on a thread, per-user, and ride along (spec 0055)',
    () async {
      final alice = InMemoryForumRepository(currentUserId: 'alice');
      final bob = alice.asUser(userId: 'bob');
      await alice.createThread(_thread('t1', authorId: 'alice'));

      await alice.toggleReaction(
        targetType: 'thread',
        targetId: 't1',
        emoji: '👍',
      );
      await bob.toggleReaction(
        targetType: 'thread',
        targetId: 't1',
        emoji: '👍',
      );
      var threads = await alice.watchThreads().first;
      expect(threads.single.reactions, hasLength(2));

      // Alice toggles hers off → only Bob's remains.
      await alice.toggleReaction(
        targetType: 'thread',
        targetId: 't1',
        emoji: '👍',
      );
      threads = await alice.watchThreads().first;
      expect(threads.single.reactions, hasLength(1));
      expect(threads.single.reactions.single.userId, 'bob');
    },
  );

  test('reactions toggle on a reply (spec 0055)', () async {
    final alice = InMemoryForumRepository(currentUserId: 'alice');
    await alice.createThread(_thread('t1'));
    await alice.postReply(_post('p1', 't1', 'hei'));

    await alice.toggleReaction(targetType: 'post', targetId: 'p1', emoji: '🎯');
    final posts = await alice.watchPosts('t1').first;
    expect(posts.single.reactions.single.emoji, '🎯');
    expect(posts.single.reactions.single.userId, 'alice');
  });
}
