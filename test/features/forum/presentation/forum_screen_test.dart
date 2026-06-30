// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the forum (spec 0054): the empty state; creating a thread
// shows it in the list; opening a thread shows its body and a posted reply;
// only the author or an admin sees the delete-thread action.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';
import 'package:treffpunkt/features/forum/presentation/forum_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';

import '../../auth/fake_auth_repository.dart';

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');

Widget _app(
  InMemoryForumRepository repo, {
  Widget home = const ForumScreen(),
}) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(initial: const SignedIn(_me)),
    ),
    forumRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(home: home),
);

InMemoryForumRepository _meRepo() =>
    InMemoryForumRepository(currentUserId: 'me')..setDisplayName('me', 'Me');

void main() {
  testWidgets('shows the empty state with no threads', (tester) async {
    await tester.pumpWidget(_app(_meRepo()));
    await tester.pumpAndSettle();
    expect(find.byKey(forumEmptyKey), findsOneWidget);
  });

  testWidgets('creating a thread shows it in the list', (tester) async {
    await tester.pumpWidget(_app(_meRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(newThreadButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(threadTitleFieldKey), 'Krasj ved skann');
    await tester.tap(find.byKey(threadCategoryKey('bug')));
    await tester.tap(find.byKey(createThreadSubmitKey));
    await tester.pumpAndSettle();

    expect(find.text('Krasj ved skann'), findsOneWidget);
    expect(find.byKey(forumEmptyKey), findsNothing);
  });

  testWidgets('opening a thread shows its body and a posted reply', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.idea,
        title: 'Ønsker mørk modus',
        body: 'Kan vi få mørk modus?',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    expect(find.text('Kan vi få mørk modus?'), findsOneWidget);

    await tester.enterText(find.byKey(forumReplyFieldKey), 'God idé!');
    await tester.tap(find.byKey(forumReplySendKey));
    await tester.pumpAndSettle();

    expect(find.text('God idé!'), findsOneWidget);
  });

  testWidgets('only the author or an admin can delete a thread', (
    tester,
  ) async {
    final repo = _meRepo();
    // A thread started by someone else.
    final other = repo.asUser(userId: 'other')..setDisplayName('other', 'Kari');
    await other.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.bug,
        title: 'Annens tråd',
        authorId: 'other',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    // A non-author, non-admin sees no delete action.
    expect(find.byKey(deleteThreadButtonKey), findsNothing);
  });

  testWidgets('an admin sees the delete-thread action', (tester) async {
    final repo = _meRepo()..addAdmin('me');
    final other = repo.asUser(userId: 'other');
    await other.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.bug,
        title: 'Annens tråd',
        authorId: 'other',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    // As an admin, the moderator can delete it.
    expect(find.byKey(deleteThreadButtonKey), findsOneWidget);
    await tester.tap(find.byKey(deleteThreadButtonKey));
    await tester.pumpAndSettle();

    // Back on the list, the thread is gone.
    expect(find.byKey(forumThreadCardKey('t1')), findsNothing);
    expect(find.byKey(forumEmptyKey), findsOneWidget);
  });

  testWidgets("reacting to another's thread adds a chip (spec 0055)", (
    tester,
  ) async {
    final repo = _meRepo();
    // A thread by someone else — you react to others', not your own.
    final other = repo.asUser(userId: 'other')..setDisplayName('other', 'Kari');
    await other.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.idea,
        title: 'Mørk modus',
        body: 'Ja takk',
        authorId: 'other',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(forumAddReactionKey('thread:t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumPaletteEmojiKey('👍')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumReactionKey('thread:t1', '👍')), findsOneWidget);
    expect(find.text('👍 1'), findsOneWidget);

    // Tapping the chip toggles it off.
    await tester.tap(find.byKey(forumReactionKey('thread:t1', '👍')));
    await tester.pumpAndSettle();
    expect(find.byKey(forumReactionKey('thread:t1', '👍')), findsNothing);
  });

  testWidgets('holding a reaction shows who reacted (spec 0059)', (
    tester,
  ) async {
    final repo = _meRepo();
    final other = repo.asUser(userId: 'other')..setDisplayName('other', 'Kari');
    await other.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.idea,
        title: 'Mørk modus',
        body: 'Ja takk',
        authorId: 'other',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(forumAddReactionKey('thread:t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumPaletteEmojiKey('👍')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(forumReactionKey('thread:t1', '👍')));
    await tester.pumpAndSettle();

    expect(find.byKey(reactorsSheetKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(reactorsSheetKey),
        matching: find.text('Me'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('you cannot react to your own thread (spec 0055)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.idea,
        title: 'Min egen tråd',
        body: 'Hei',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    // No "add reaction" affordance on your own opening post.
    expect(find.byKey(forumAddReactionKey('thread:t1')), findsNothing);
  });

  testWidgets('a thread with an image shows the picture (spec 0056)', (
    tester,
  ) async {
    final repo = _meRepo();
    final path = await repo.uploadForumImage(
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    await repo.createThread(
      ForumThread(
        id: 't1',
        category: ForumCategory.bug,
        title: 'Med bilde',
        imagePath: path,
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumImageKey('t1')), findsOneWidget);
  });

  testWidgets('attaching an image to a reply posts it (spec 0056)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    final picked = XFile.fromData(
      Uint8List.fromList(<int>[1, 2, 3]),
      name: 'x.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          forumRepositoryProvider.overrideWithValue(repo),
          forumImagePickerProvider.overrideWithValue(() async => picked),
        ],
        child: const MaterialApp(
          home: ForumThreadScreen(
            thread: ForumThread(
              id: 't1',
              category: ForumCategory.bug,
              title: 'T',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(forumReplyAttachKey));
    await tester.pump();

    final posts = await repo.watchPosts('t1').first;
    expect(posts, hasLength(1));
    expect(posts.single.imagePath, isNotNull);
  });

  testWidgets('pasting an image in a reply posts it (spec 0062)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    final clipboard = FakeClipboardImageWatcher();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          forumRepositoryProvider.overrideWithValue(repo),
          clipboardImageWatcherProvider.overrideWithValue(clipboard),
        ],
        child: const MaterialApp(
          home: ForumThreadScreen(
            thread: ForumThread(
              id: 't1',
              category: ForumCategory.bug,
              title: 'T',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    clipboard.emit(
      PastedImage(bytes: Uint8List.fromList(<int>[1, 2, 3]), isPng: false),
    );
    await tester.pumpAndSettle();

    final posts = await repo.watchPosts('t1').first;
    expect(posts, hasLength(1));
    expect(posts.single.imagePath, isNotNull);
  });

  testWidgets('pasting an image in the new-thread form attaches it (0062)', (
    tester,
  ) async {
    final repo = _meRepo();
    final clipboard = FakeClipboardImageWatcher();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          forumRepositoryProvider.overrideWithValue(repo),
          clipboardImageWatcherProvider.overrideWithValue(clipboard),
        ],
        child: const MaterialApp(home: NewThreadScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(threadImageAttachedKey), findsNothing);

    clipboard.emit(
      PastedImage(bytes: Uint8List.fromList(<int>[1, 2, 3]), isPng: true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(threadImageAttachedKey), findsOneWidget);
  });

  testWidgets('editing your own reply shows the new text (spec 0063)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    await repo.postReply(
      const ForumPost(id: 'p1', threadId: 't1', body: 'feil tekst'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();
    expect(find.text('feil tekst'), findsOneWidget);

    await tester.longPress(find.byKey(forumPostKey('p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumReplyEditKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(forumEditBodyFieldKey), 'rettet tekst');
    await tester.tap(find.byKey(forumEditSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('rettet tekst'), findsOneWidget);
    expect(find.text('feil tekst'), findsNothing);
  });

  testWidgets('editing your own thread updates its title (spec 0063)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.bug,
        title: 'Gammel tittel',
        body: 'tekst',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(editThreadButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(forumEditTitleFieldKey), 'Ny tittel');
    await tester.tap(find.byKey(forumEditSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('Ny tittel'), findsOneWidget);
  });
}

/// A clipboard watcher whose paste stream the test drives.
class FakeClipboardImageWatcher implements ClipboardImageWatcher {
  final StreamController<PastedImage> _controller =
      StreamController<PastedImage>.broadcast();

  @override
  Stream<PastedImage> get images => _controller.stream;

  void emit(PastedImage image) => _controller.add(image);

  void dispose() => unawaited(_controller.close());
}
