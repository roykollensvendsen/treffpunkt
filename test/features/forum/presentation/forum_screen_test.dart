// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the forum (spec 0054): the empty state; creating a thread
// shows it in the list; opening a thread shows its body and a posted reply;
// only the author or an admin sees the delete-thread action.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/platform/image_format.dart';
import 'package:treffpunkt/core/presentation/full_screen_image.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';
import 'package:treffpunkt/features/forum/presentation/forum_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';

import '../../auth/fake_auth_repository.dart';

/// Minimal valid headers so the upload's format detection accepts them.
final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  13,
  10,
  26,
  10,
]);
final Uint8List _gifBytes = Uint8List.fromList(<int>[
  0x47,
  0x49,
  0x46,
  0x38,
  0x39,
  0x61,
]);

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');

Widget _app(
  InMemoryForumRepository repo, {
  Widget home = const ForumScreen(),
  String? displayName = 'Me',
}) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(initial: const SignedIn(_me)),
    ),
    forumRepositoryProvider.overrideWithValue(repo),
    // Posting is gated on a display name (spec 0072); the current user "me"
    // has one by default so the existing posting tests are not blocked. Pass
    // displayName: null to exercise the "choose a name first" gate.
    competitionRepositoryProvider.overrideWithValue(_profileRepo(displayName)),
  ],
  child: MaterialApp(home: home),
);

/// A thread screen wired to a paste [clipboard], for the image-paste tests.
Widget _pasteApp(
  InMemoryForumRepository repo,
  FakeClipboardImageWatcher clipboard,
) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(initial: const SignedIn(_me)),
    ),
    forumRepositoryProvider.overrideWithValue(repo),
    clipboardImageWatcherProvider.overrideWithValue(clipboard),
  ],
  child: const MaterialApp(
    home: ForumThreadScreen(
      thread: ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    ),
  ),
);

/// A competition repo whose current user "me" has the given [displayName] (or
/// none). The in-memory upsert is synchronous, so the profile is set at once.
InMemoryCompetitionRepository _profileRepo(String? displayName) {
  final repo = InMemoryCompetitionRepository(currentUserId: 'me');
  unawaited(repo.upsertOwnProfile(Profile(id: 'me', displayName: displayName)));
  return repo;
}

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

  testWidgets('posting with no brukernavn asks for one first (spec 0072)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_meRepo(), displayName: null));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(newThreadButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(threadTitleFieldKey), 'Ny sak');
    await tester.tap(find.byKey(threadCategoryKey('bug')));
    await tester.tap(find.byKey(createThreadSubmitKey));
    await tester.pumpAndSettle();

    // A "choose a name" prompt appears instead of creating the thread.
    expect(find.byKey(displayNameFieldKey), findsOneWidget);

    await tester.enterText(find.byKey(displayNameFieldKey), 'Blink');
    await tester.tap(find.byKey(displayNameSaveKey));
    await tester.pumpAndSettle();

    // With a name set, the thread is created and shown in the list.
    expect(find.text('Ny sak'), findsOneWidget);
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
    // Deleting confirms first (spec 0096).
    await tester.tap(find.byKey(confirmForumDeleteKey));
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

    // Tapping the picture opens the zoomable full-screen viewer (spec 0073).
    await tester.tap(find.byKey(forumImageKey('t1')));
    await tester.pumpAndSettle();
    expect(find.byKey(fullScreenImageKey), findsOneWidget);
  });

  testWidgets('attaching an image to a reply posts it (spec 0056)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    final picked = XFile.fromData(_pngBytes, name: 'x.png');

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

    clipboard.emit(PastedImage(bytes: _pngBytes, isPng: false));
    await tester.pumpAndSettle();

    final posts = await repo.watchPosts('t1').first;
    expect(posts, hasLength(1));
    expect(posts.single.imagePath, isNotNull);
  });

  testWidgets('a pasted GIF reply is accepted (spec 0075)', (tester) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    final clipboard = FakeClipboardImageWatcher();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(_pasteApp(repo, clipboard));
    await tester.pump();

    clipboard.emit(PastedImage(bytes: _gifBytes, isPng: false));
    await tester.pumpAndSettle();

    expect(
      (await repo.watchPosts('t1').first).single.imagePath,
      endsWith('.gif'),
    );
  });

  testWidgets('an unsupported reply file is refused (spec 0075)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    final clipboard = FakeClipboardImageWatcher();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(_pasteApp(repo, clipboard));
    await tester.pump();

    clipboard.emit(
      PastedImage(bytes: Uint8List.fromList(<int>[1, 2, 3, 4]), isPng: false),
    );
    await tester.pumpAndSettle();

    expect(find.text(unsupportedImageMessage), findsOneWidget);
    expect(await repo.watchPosts('t1').first, isEmpty);
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

    clipboard.emit(PastedImage(bytes: _pngBytes, isPng: true));
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

  testWidgets('a Robot-prefixed reply wears the robot identity (0112)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    // The agent's clarifying questions are posted from Roy's own account
    // with the «Robot: » prefix; the UI turns that into a robot identity.
    await repo.postReply(
      const ForumPost(id: 'p1', threadId: 't1', body: 'Robot: Hvilken skive?'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    // Robot byline with the icon; the prefix itself is not shown.
    expect(find.text('Robot'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(find.text('Hvilken skive?'), findsOneWidget);
    expect(find.textContaining('Robot: '), findsNothing);
    // Even the author's own robot posts read as the robot, not as "mine":
    // the bubble sits on the left like any other participant's.
    final bubble = tester.getTopLeft(find.byKey(forumPostKey('p1')));
    expect(bubble.dx, lessThan(200));
  });

  testWidgets('long-pressing a reply copies its text (spec 0069)', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    await repo.postReply(
      const ForumPost(id: 'p1', threadId: 't1', body: 'svar å kopiere'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(forumPostKey('p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumReplyCopyKey));
    await tester.pumpAndSettle();

    expect((calls.single.arguments as Map)['text'], 'svar å kopiere');
    expect(find.text('Tekst kopiert'), findsOneWidget);
  });

  testWidgets("long-pressing a thread's body copies it (spec 0069)", (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(
        id: 't1',
        category: ForumCategory.bug,
        title: 'T',
        body: 'tråd å kopiere',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('tråd å kopiere'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCopyKey));
    await tester.pumpAndSettle();

    expect((calls.single.arguments as Map)['text'], 'tråd å kopiere');
    expect(find.text('Tekst kopiert'), findsOneWidget);
  });

  testWidgets('a moderator sets the status and it shows a badge (0066)', (
    tester,
  ) async {
    final repo = _meRepo()..addAdmin('me');
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(forumStatusMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumStatusOptionKey('done')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumStatusBadgeKey('t1')), findsOneWidget);
    expect(find.text('Ferdig'), findsWidgets);
  });

  testWidgets('«Jobber med» is offered and badged (spec 0117)', (
    tester,
  ) async {
    final repo = _meRepo()..addAdmin('me');
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(forumStatusMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumStatusOptionKey('in_progress')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumStatusBadgeKey('t1')), findsOneWidget);
    expect(find.text('Jobber med'), findsWidgets);
  });

  testWidgets('a non-moderator sees no status menu (spec 0066)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumStatusMenuKey), findsNothing);
  });

  testWidgets('a thread and reply show a timestamp (spec 0065)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    await repo.postReply(
      const ForumPost(id: 'p1', threadId: 't1', body: 'hei'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(forumTimeKey('t1')), findsOneWidget);
    expect(find.byKey(forumTimeKey('p1')), findsOneWidget);
  });

  testWidgets('your own reply is right-aligned, others left (spec 0064)', (
    tester,
  ) async {
    final repo = _meRepo()..setDisplayName('other', 'Kari');
    await repo.createThread(
      const ForumThread(id: 't1', category: ForumCategory.bug, title: 'T'),
    );
    await repo.postReply(
      const ForumPost(id: 'mine', threadId: 't1', body: 'mitt svar'),
    );
    await repo
        .asUser(userId: 'other')
        .postReply(
          const ForumPost(
            id: 'theirs',
            threadId: 't1',
            body: 'kari svar',
            authorId: 'other',
          ),
        );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(forumThreadCardKey('t1')));
    await tester.pumpAndSettle();

    Alignment alignmentOf(String id) {
      final align = tester.widget<Align>(
        find
            .ancestor(
              of: find.byKey(forumPostKey(id)),
              matching: find.byType(Align),
            )
            .first,
      );
      return align.alignment as Alignment;
    }

    expect(alignmentOf('mine'), Alignment.centerRight);
    expect(alignmentOf('theirs'), Alignment.centerLeft);
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
