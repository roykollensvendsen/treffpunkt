// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the competition chat (spec 0051): sending shows your
// message; an incoming message from another shooter appears with their name;
// deleting your own message removes it. Driven by the in-memory repository's
// Realtime stand-in (watchMessages).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.longPress(find.byKey(chatMessageKey('m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slett'));
    await tester.pumpAndSettle();

    expect(find.text('slett meg'), findsNothing);
  });
}
