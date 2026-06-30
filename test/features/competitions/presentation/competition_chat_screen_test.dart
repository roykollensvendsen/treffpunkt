// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the competition chat (spec 0051): sending shows your
// message; an incoming message from another shooter appears with their name;
// deleting your own message removes it. Driven by the in-memory repository's
// Realtime stand-in (watchMessages).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_message.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_chat_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';

import '../../auth/fake_auth_repository.dart';

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');
const _competition = Competition(
  id: 'c1',
  name: 'Vårcup',
  program: '25 m NAIS fin',
  ownerId: 'me',
);

Widget _app(InMemoryCompetitionRepository repo) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(initial: const SignedIn(_me)),
    ),
    competitionRepositoryProvider.overrideWithValue(repo),
  ],
  child: const MaterialApp(
    home: CompetitionChatScreen(competition: _competition),
  ),
);

InMemoryCompetitionRepository _meRepo() => InMemoryCompetitionRepository(
  currentUserId: 'me',
  currentEmail: 'me@example.com',
);

void main() {
  testWidgets('sending a message shows it in the chat', (tester) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(chatEmptyKey), findsOneWidget);

    await tester.enterText(find.byKey(chatComposerFieldKey), 'Hei alle!');
    await tester.tap(find.byKey(chatSendButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Hei alle!'), findsOneWidget);
    expect(find.byKey(chatEmptyKey), findsNothing);
  });

  testWidgets('an incoming message shows with its author name', (tester) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    // Another shooter joins and posts before the screen opens.
    final other = repo.asUser(userId: 'other', email: 'other@example.com');
    await other.upsertOwnProfile(
      const Profile(id: 'other', displayName: 'Kari'),
    );
    await repo.invite('c1', 'other@example.com');
    await other.acceptInvitation('c1');
    await other.postMessage(
      const CompetitionMessage(
        id: 'm1',
        competitionId: 'c1',
        body: 'Hallo fra Kari',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Hallo fra Kari'), findsOneWidget);
    // Other shooters' messages carry their name.
    expect(find.text('Kari'), findsOneWidget);
  });

  testWidgets('deleting your own message removes it', (tester) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    await repo.postMessage(
      const CompetitionMessage(
        id: 'm1',
        competitionId: 'c1',
        body: 'slett meg',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('slett meg'), findsOneWidget);

    // Long-press opens the action sheet; "Slett" there asks to confirm.
    await tester.longPress(find.byKey(chatMessageKey('m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(chatDeleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett'));
    await tester.pumpAndSettle();

    expect(find.text('slett meg'), findsNothing);
  });

  testWidgets('long-pressing a message copies its text (spec 0069)', (
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
    await repo.createCompetition(_competition);
    await repo.postMessage(
      const CompetitionMessage(
        id: 'm1',
        competitionId: 'c1',
        body: 'kopier meg',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(chatMessageKey('m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(chatCopyKey));
    await tester.pumpAndSettle();

    expect((calls.single.arguments as Map)['text'], 'kopier meg');
    expect(find.text('Tekst kopiert'), findsOneWidget);
  });

  testWidgets('reacting to another shooter adds a chip, then removes it', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    // A message from ANOTHER participant — you react to others', not your own.
    final other = repo.asUser(userId: 'other', email: 'other@example.com');
    await repo.invite('c1', 'other@example.com');
    await other.acceptInvitation('c1');
    await other.postMessage(
      const CompetitionMessage(id: 'm1', competitionId: 'c1', body: 'hei'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the palette and pick 👍.
    await tester.tap(find.byKey(chatAddReactionKey('m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(chatPaletteEmojiKey('👍')));
    await tester.pumpAndSettle();

    expect(find.byKey(chatReactionKey('m1', '👍')), findsOneWidget);
    expect(find.text('👍 1'), findsOneWidget);

    // Tapping the chip toggles my reaction off again.
    await tester.tap(find.byKey(chatReactionKey('m1', '👍')));
    await tester.pumpAndSettle();
    expect(find.byKey(chatReactionKey('m1', '👍')), findsNothing);
  });

  testWidgets('holding a reaction shows who reacted (spec 0059)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    await repo.createCompetition(_competition);
    final other = repo.asUser(userId: 'other', email: 'other@example.com');
    await repo.invite('c1', 'other@example.com');
    await other.acceptInvitation('c1');
    await other.postMessage(
      const CompetitionMessage(id: 'm1', competitionId: 'c1', body: 'hei'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // React, then hold the chip to open the "who reacted" sheet.
    await tester.tap(find.byKey(chatAddReactionKey('m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(chatPaletteEmojiKey('👍')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(chatReactionKey('m1', '👍')));
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

  testWidgets('you cannot react to your own message (spec 0052)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    await repo.postMessage(
      const CompetitionMessage(
        id: 'm1',
        competitionId: 'c1',
        body: 'mi melding',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // No "add reaction" affordance on your own message.
    expect(find.byKey(chatAddReactionKey('m1')), findsNothing);
  });

  testWidgets('an image message renders the picture (spec 0053)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    final path = await repo.uploadChatImage(
      'c1',
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    await repo.postMessage(
      CompetitionMessage(
        id: 'm1',
        competitionId: 'c1',
        body: '',
        imagePath: path,
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pump();

    expect(find.byKey(chatImageKey('m1')), findsOneWidget);
  });

  testWidgets('attaching an image uploads and posts it (spec 0053)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    final picked = XFile.fromData(
      Uint8List.fromList(<int>[1, 2, 3]),
      name: 'shot.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          competitionRepositoryProvider.overrideWithValue(repo),
          imagePickerProvider.overrideWithValue(() async => picked),
        ],
        child: const MaterialApp(
          home: CompetitionChatScreen(competition: _competition),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(chatAttachImageKey));
    await tester.pump();

    // The picked image was uploaded and posted as a message.
    final chat = await repo.watchMessages('c1').first;
    expect(chat, hasLength(1));
    expect(chat.single.imagePath, isNotNull);
  });

  testWidgets('pasting an image uploads and posts it (spec 0062)', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    final clipboard = FakeClipboardImageWatcher();
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          competitionRepositoryProvider.overrideWithValue(repo),
          clipboardImageWatcherProvider.overrideWithValue(clipboard),
        ],
        child: const MaterialApp(
          home: CompetitionChatScreen(competition: _competition),
        ),
      ),
    );
    await tester.pump();

    clipboard.emit(
      PastedImage(bytes: Uint8List.fromList(<int>[1, 2, 3]), isPng: true),
    );
    await tester.pumpAndSettle();

    final chat = await repo.watchMessages('c1').first;
    expect(chat, hasLength(1));
    expect(chat.single.imagePath, isNotNull);
  });

  testWidgets('a message shows a timestamp (spec 0065)', (tester) async {
    final repo = _meRepo();
    await repo.createCompetition(_competition);
    await repo.postMessage(
      const CompetitionMessage(id: 'm1', competitionId: 'c1', body: 'hei'),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(chatTimestampKey('m1')), findsOneWidget);
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
