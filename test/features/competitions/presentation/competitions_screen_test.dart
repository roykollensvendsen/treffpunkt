// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the competitions UI (spec 0011): the empty state; creating a
// competition makes it appear in "Mine konkurranser"; accepting an invitation
// moves it into the list; and the owner can invite someone by email.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_message.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_chat_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_invite_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_result_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

import '../../auth/fake_auth_repository.dart';

const _me = AppUser(id: 'me', email: 'me@example.com', displayName: 'Me');

Widget _app(
  InMemoryCompetitionRepository repo, {
  String newId = 'new-1',
  Widget home = const CompetitionsScreen(),
}) {
  final auth = FakeAuthRepository(initial: const SignedIn(_me));
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      competitionRepositoryProvider.overrideWithValue(repo),
      competitionIdGeneratorProvider.overrideWithValue(() => newId),
    ],
    child: MaterialApp(home: home),
  );
}

InMemoryCompetitionRepository _meRepo() => InMemoryCompetitionRepository(
  currentUserId: 'me',
  currentEmail: 'me@example.com',
);

/// Records shared text instead of opening the real OS share sheet.
class _RecordingSharer implements Sharer {
  final List<String> shared = <String>[];
  @override
  Future<void> share(String text) async => shared.add(text);
}

void main() {
  testWidgets('shows the empty state with no competitions', (tester) async {
    await tester.pumpWidget(_app(_meRepo()));
    await tester.pumpAndSettle();
    expect(find.byKey(noCompetitionsKey), findsOneWidget);
  });

  testWidgets('creating a competition makes it appear in the list', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_meRepo(), newId: 'created-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(newCompetitionButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(competitionNameFieldKey), 'Klubbmatch');
    // An optional event-date field is offered (spec 0057).
    expect(find.byKey(competitionDateFieldKey), findsOneWidget);
    await tester.tap(find.byKey(createCompetitionSubmitKey));
    await tester.pumpAndSettle();

    // Back on the hub, the new competition is listed.
    expect(find.byKey(competitionCard('created-1')), findsOneWidget);
    expect(find.text('Klubbmatch'), findsOneWidget);
  });

  testWidgets('accepting an invitation moves it into my competitions', (
    tester,
  ) async {
    final repo = _meRepo();
    // Another user owns a competition and invites me.
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Alice Cup',
        program: '25 m NAIS fin',
        ownerId: 'alice',
      ),
    );
    await alice.invite('c1', 'me@example.com');

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // The invitation is offered; the competition is not yet in my list.
    expect(find.byKey(acceptInvitationKey('c1')), findsOneWidget);
    expect(find.byKey(competitionCard('c1')), findsNothing);

    await tester.tap(find.byKey(acceptInvitationKey('c1')));
    await tester.pumpAndSettle();

    // After accepting, it moves into my competitions and the invite is gone.
    expect(find.byKey(acceptInvitationKey('c1')), findsNothing);
    expect(find.byKey(competitionCard('c1')), findsOneWidget);
    expect(find.text('Alice Cup'), findsOneWidget);
  });

  testWidgets('the detail leads with results; Inviter opens its page (0093)', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    // No inline invite machinery: one compact Inviter action instead, and
    // the results section sits above the participants.
    expect(find.byKey(shareInviteKey), findsNothing);
    expect(find.byKey(shooterPickerKey), findsNothing);
    expect(find.byKey(inviteCompetitionKey), findsOneWidget);
    final resultsY = tester.getTopLeft(find.text('Resultater')).dy;
    final membersY = tester.getTopLeft(find.text('Deltakere')).dy;
    expect(resultsY, lessThan(membersY));

    // The Inviter action opens the dedicated invite page with both
    // mechanisms (specs 0048/0032).
    await tester.tap(find.byKey(inviteCompetitionKey));
    await tester.pumpAndSettle();
    expect(find.byType(CompetitionInviteScreen), findsOneWidget);
    expect(find.byKey(shareInviteKey), findsOneWidget);
    expect(find.text('Inviter med lenke'), findsOneWidget);
  });

  testWidgets('the owner shares and copies a join link', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    final sharer = _RecordingSharer();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(_me)),
          ),
          competitionRepositoryProvider.overrideWithValue(repo),
          sharerProvider.overrideWithValue(sharer),
          appBaseUrlProvider.overrideWithValue(
            Uri.parse('https://app.example/treffpunkt/'),
          ),
        ],
        child: const MaterialApp(
          home: CompetitionInviteScreen(competition: competition),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Share opens the OS sheet with a link carrying the competition + token.
    await tester.tap(find.byKey(shareInviteKey));
    await tester.pumpAndSettle();
    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single, contains('https://app.example/treffpunkt/'));
    expect(sharer.shared.single, contains('join=c1'));
    expect(sharer.shared.single, contains('token='));

    // Copy is the reliable fallback — the same link reaches the clipboard.
    await tester.tap(find.byKey(copyInviteLinkKey));
    await tester.pumpAndSettle();
    expect(copied, contains('join=c1'));
    expect(find.text('Lenke kopiert.'), findsOneWidget);

    // Regenerating issues a fresh link.
    await tester.tap(find.byKey(regenerateLinkKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ny lenke'), findsOneWidget);
  });

  testWidgets('the picker hides only the owner; a member reads "Deltar"', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    final bob = repo.asUser(userId: 'bob', email: 'bob@example.com');
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));
    // Alice accepted her invitation, so she is now a member.
    await repo.inviteUser('c1', 'alice');
    await alice.acceptInvitation('c1');

    await tester.pumpWidget(
      _app(repo, home: const CompetitionInviteScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    // The owner is hidden; Bob is invitable; Alice (member) reads "Deltar".
    expect(find.byKey(shooterPickerKey), findsOneWidget);
    expect(find.byKey(shooterTileKey('me')), findsNothing);
    expect(find.byKey(shooterTileKey('bob')), findsOneWidget);
    final aliceTile = find.byKey(inviteShooterButtonKey('alice'));
    expect(
      find.descendant(of: aliceTile, matching: find.text('Deltar')),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(aliceTile).onPressed, isNull);

    await tester.tap(find.byKey(inviteShooterButtonKey('bob')));
    await tester.pumpAndSettle();

    // Picking Bob invited him — no email was ever typed or shown.
    final invitations = await bob.listMyInvitations();
    expect(invitations.map((i) => i.competitionId), <String>['c1']);
  });

  testWidgets('an invited shooter settles to "Invitert" and cannot be '
      're-invited', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final bob = repo.asUser(userId: 'bob', email: 'bob@example.com');
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));

    await tester.pumpWidget(
      _app(repo, home: const CompetitionInviteScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(inviteShooterButtonKey('bob')));
    await tester.pumpAndSettle();

    // The button settles to a disabled "Invitert": a second tap can't fire.
    final tile = find.byKey(inviteShooterButtonKey('bob'));
    expect(
      find.descendant(of: tile, matching: find.text('Invitert')),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(tile).onPressed, isNull);
    expect(
      find.descendant(of: tile, matching: find.text('Inviter')),
      findsNothing,
    );
  });

  testWidgets('a shooter invited in an earlier visit loads as "Invitert"', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final bob = repo.asUser(userId: 'bob', email: 'bob@example.com');
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));
    // Bob was invited before this screen opened (a previous visit) — the
    // pending-invitee lookup, not session state, must mark him.
    await repo.inviteUser('c1', 'bob');

    await tester.pumpWidget(
      _app(repo, home: const CompetitionInviteScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    // Settled on load, with no tap this visit.
    final tile = find.byKey(inviteShooterButtonKey('bob'));
    expect(
      find.descendant(of: tile, matching: find.text('Invitert')),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(tile).onPressed, isNull);
  });

  testWidgets('inviting one shooter does not disable the others', (
    tester,
  ) async {
    final inner = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await inner.createCompetition(competition);
    await inner.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final alice = inner.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    final bob = inner.asUser(userId: 'bob', email: 'bob@example.com');
    await bob.upsertOwnProfile(const Profile(id: 'bob', displayName: 'Bob'));
    final gate = Completer<void>();
    final repo = _GatedInviteRepository(inner, gate);

    final auth = FakeAuthRepository(initial: const SignedIn(_me));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          competitionRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: CompetitionInviteScreen(competition: competition),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Bob's invite; the invite parks on the gate so it is still in flight.
    await tester.tap(find.byKey(inviteShooterButtonKey('bob')));
    await tester.pump();

    // Only Bob's button is disabled — Alice's stays tappable (no shared blink).
    expect(_inviteEnabled(tester, inviteShooterButtonKey('bob')), isFalse);
    expect(_inviteEnabled(tester, inviteShooterButtonKey('alice')), isTrue);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a non-owner sees no invite controls', (tester) async {
    final repo = _meRepo();
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    const competition = Competition(
      id: 'c1',
      name: 'Alice Cup',
      program: '25 m NAIS fin',
      ownerId: 'alice',
    );
    await alice.createCompetition(competition);
    await alice.invite('c1', 'me@example.com');
    await repo.acceptInvitation('c1'); // me joins as a member, not the owner

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(inviteCompetitionKey), findsNothing);
    expect(find.byKey(shooterPickerKey), findsNothing);
    expect(find.byKey(shareInviteKey), findsNothing);

    // The overflow menu offers archive but never delete (spec 0093).
    await tester.tap(find.byKey(competitionMenuKey));
    await tester.pumpAndSettle();
    expect(find.byKey(toggleArchiveButtonKey), findsOneWidget);
    expect(find.byKey(deleteCompetitionButtonKey), findsNothing);
  });

  testWidgets('the owner deletes the competition and returns to the hub', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    // Start on the hub, open the detail, then delete.
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(competitionCard('c1')), findsOneWidget);
    await tester.tap(find.byKey(competitionCard('c1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(competitionMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteCompetitionButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteCompetitionConfirmKey));
    await tester.pumpAndSettle();

    // Back on the hub; the competition is gone.
    expect(find.byKey(competitionCard('c1')), findsNothing);
    expect(find.byKey(noCompetitionsKey), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the competition', (tester) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(competitionMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(deleteCompetitionButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    // Still on the detail screen — nothing deleted.
    expect(find.byKey(competitionMenuKey), findsOneWidget);
  });

  testWidgets('the detail shows the scoreboard, best first', (tester) async {
    // A tall viewport so the whole detail (chat button, scoreboard, members)
    // builds — the scoreboard rows sit below a short screen's build extent.
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    await repo.upsertOwnProfile(const Profile(id: 'me', displayName: 'Me'));
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await repo.submitResult(_res('r-me', user: 'me', total: 560));
    await alice.submitResult(_res('r-alice', user: 'alice', total: 580));

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(noResultsKey), findsNothing);
    expect(find.byKey(resultRowKey('r-alice')), findsOneWidget);
    expect(find.byKey(resultRowKey('r-me')), findsOneWidget);
    // Alice's name shows on her scoreboard row (she also appears in the invite
    // picker as a registered non-member, so scope the check to the row).
    expect(
      find.descendant(
        of: find.byKey(resultRowKey('r-alice')),
        matching: find.text('Alice'),
      ),
      findsOneWidget,
    );
    expect(find.text('580'), findsOneWidget);
    // Best first: Alice's row sits above Me's.
    final aliceTop = tester.getTopLeft(find.byKey(resultRowKey('r-alice'))).dy;
    final meTop = tester.getTopLeft(find.byKey(resultRowKey('r-me'))).dy;
    expect(aliceTop, lessThan(meTop));
  });

  testWidgets('tapping a shooter opens their full scorecard', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Luftpistol 60 skudd',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await alice.submitResult(_realResult('r-alice', user: 'alice'));

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(resultRowKey('r-alice')));
    await tester.pumpAndSettle();

    // Alice's full scorecard opens, titled with her name.
    expect(find.byType(CompetitionResultScreen), findsOneWidget);
    expect(find.byKey(sessionCompleteKey), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Alice'), findsOneWidget);
  });

  testWidgets('a result with an unreadable payload shows a message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Luftpistol 60 skudd',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    // An empty payload cannot be rebuilt into a session.
    await alice.submitResult(_res('r-bad', user: 'alice', total: 500));

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(resultRowKey('r-bad')));
    await tester.pumpAndSettle();

    expect(find.byKey(unreadableResultKey), findsOneWidget);
  });

  testWidgets('the scoreboard updates live when a result is submitted', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(noResultsKey), findsOneWidget); // empty board

    // Another participant submits — the live stream updates the board with no
    // reopen.
    final alice = repo.asUser(userId: 'alice', email: 'alice@example.com');
    await alice.upsertOwnProfile(
      const Profile(id: 'alice', displayName: 'Alice'),
    );
    await alice.submitResult(_res('r-alice', user: 'alice', total: 575));
    await tester.pumpAndSettle();

    expect(find.byKey(noResultsKey), findsNothing);
    expect(find.byKey(resultRowKey('r-alice')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('Skyt nå opens setup for the competition program', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'My Cup',
      program: '10 m Air Pistol',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(shootForCompetitionKey));
    await tester.pumpAndSettle();

    // The setup step for the competition's fixed program is shown.
    expect(find.byType(SessionSetupScreen), findsOneWidget);
    expect(
      find.widgetWithText(AppBar, '10 m Luftpistol 60 skudd'),
      findsOneWidget,
    );
  });

  testWidgets('the calendar filters competitions by event date (spec 0057)', (
    tester,
  ) async {
    // A tall viewport so the open calendar and the competition cards all build.
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _meRepo();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 15); // mid this month
    await repo.createCompetition(
      Competition(
        id: 'dated',
        name: 'Sommercup',
        program: '25 m NAIS fin',
        ownerId: 'me',
        eventDate: day,
      ),
    );
    await repo.createCompetition(
      const Competition(
        id: 'undated',
        name: 'Løpende cup',
        program: '25 m NAIS fin',
        ownerId: 'me',
      ),
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Both are shown before filtering.
    expect(find.byKey(competitionCard('dated')), findsOneWidget);
    expect(find.byKey(competitionCard('undated')), findsOneWidget);

    // Open the calendar and pick the 15th → only that day's competition.
    await tester.tap(find.byKey(competitionCalendarToggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(competitionCalendarDayKey(day)));
    await tester.pumpAndSettle();

    expect(find.byKey(competitionCard('dated')), findsOneWidget);
    expect(find.byKey(competitionCard('undated')), findsNothing);

    // "Vis alle" clears the filter.
    await tester.tap(find.byKey(competitionCalendarClearKey));
    await tester.pumpAndSettle();
    expect(find.byKey(competitionCard('undated')), findsOneWidget);
  });

  testWidgets('the detail opens the competition chat (spec 0051)', (
    tester,
  ) async {
    final repo = _meRepo();
    const competition = Competition(
      id: 'c1',
      name: 'Vårcup',
      program: '25 m NAIS fin',
      ownerId: 'me',
    );
    await repo.createCompetition(competition);

    await tester.pumpWidget(
      _app(repo, home: const CompetitionDetailScreen(competition: competition)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(competitionChatButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(CompetitionChatScreen), findsOneWidget);
    expect(find.byKey(chatComposerFieldKey), findsOneWidget);
  });

  testWidgets('archiving from the list moves it to the Arkiverte section', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Vårcup',
        program: '25 m NAIS fin',
        ownerId: 'me',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // It starts active: no archived section, an archive action present.
    expect(find.byKey(archivedSectionKey), findsNothing);
    expect(find.byKey(archiveCompetitionKey('c1')), findsOneWidget);

    await tester.tap(find.byKey(archiveCompetitionKey('c1')));
    await tester.pumpAndSettle();

    // The collapsed "Arkiverte" tile appears; the archive action is gone, and
    // the archived competition stays tucked away until the tile is expanded.
    expect(find.byKey(archivedSectionKey), findsOneWidget);
    expect(find.byKey(archiveCompetitionKey('c1')), findsNothing);
    expect(find.byKey(unarchiveCompetitionKey('c1')), findsNothing);
    expect(await repo.archivedCompetitionIds(), <String>{'c1'});

    // Expanding it reveals the archived competition with a restore action.
    await tester.tap(find.byKey(archivedSectionKey));
    await tester.pumpAndSettle();
    expect(find.byKey(unarchiveCompetitionKey('c1')), findsOneWidget);
  });

  testWidgets('restoring returns an archived competition to the active list', (
    tester,
  ) async {
    final repo = _meRepo();
    await repo.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Vårcup',
        program: '25 m NAIS fin',
        ownerId: 'me',
      ),
    );
    await repo.archiveCompetition('c1');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Expand the collapsed "Arkiverte" tile to reach the restore action.
    expect(find.byKey(archivedSectionKey), findsOneWidget);
    await tester.tap(find.byKey(archivedSectionKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(unarchiveCompetitionKey('c1')));
    await tester.pumpAndSettle();

    expect(find.byKey(archivedSectionKey), findsNothing);
    expect(find.byKey(archiveCompetitionKey('c1')), findsOneWidget);
    expect(await repo.archivedCompetitionIds(), isEmpty);
  });

  testWidgets('a joined competition you do not own is archivable from detail', (
    tester,
  ) async {
    final repo = _meRepo();
    // A competition owned by someone else that "me" joins via invite + accept.
    final other = repo.asUser(userId: 'other', email: 'other@example.com');
    await other.createCompetition(
      const Competition(
        id: 'c1',
        name: 'Klubbmesterskap',
        program: '25 m NAIS fin',
        ownerId: 'other',
      ),
    );
    await other.invite('c1', 'me@example.com');
    await repo.acceptInvitation('c1');

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(competitionCard('c1')));
    await tester.pumpAndSettle();

    // A non-owner has no delete action, but can archive.
    expect(find.byKey(deleteCompetitionButtonKey), findsNothing);
    await tester.tap(find.byKey(competitionMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(toggleArchiveButtonKey));
    await tester.pumpAndSettle();

    // Popped back to the list; it now sits under the collapsed "Arkiverte"
    // tile, revealed on expand.
    expect(await repo.archivedCompetitionIds(), <String>{'c1'});
    expect(find.byKey(archivedSectionKey), findsOneWidget);
    await tester.tap(find.byKey(archivedSectionKey));
    await tester.pumpAndSettle();
    expect(find.byKey(unarchiveCompetitionKey('c1')), findsOneWidget);
  });
}

bool _inviteEnabled(WidgetTester tester, Key key) =>
    tester.widget<FilledButton>(find.byKey(key)).onPressed != null;

/// Wraps an in-memory repository but parks `inviteUser` on a gate, so a test
/// can observe the in-flight state — only the tapped shooter's button should be
/// disabled, never all of them. Every other call delegates straight through.
class _GatedInviteRepository implements CompetitionRepository {
  _GatedInviteRepository(this._inner, this._gate);

  final InMemoryCompetitionRepository _inner;
  final Completer<void> _gate;

  @override
  Future<void> inviteUser(String competitionId, String userId) async {
    await _gate.future;
    await _inner.inviteUser(competitionId, userId);
  }

  @override
  Future<void> upsertOwnProfile(Profile profile) =>
      _inner.upsertOwnProfile(profile);
  @override
  Future<Profile?> fetchProfile(String id) => _inner.fetchProfile(id);
  @override
  Future<void> createCompetition(Competition competition) =>
      _inner.createCompetition(competition);
  @override
  Future<List<Competition>> listMine() => _inner.listMine();
  @override
  Future<void> deleteCompetition(String competitionId) =>
      _inner.deleteCompetition(competitionId);
  @override
  Future<Set<String>> archivedCompetitionIds() =>
      _inner.archivedCompetitionIds();
  @override
  Future<void> archiveCompetition(String competitionId) =>
      _inner.archiveCompetition(competitionId);
  @override
  Future<void> unarchiveCompetition(String competitionId) =>
      _inner.unarchiveCompetition(competitionId);
  @override
  Future<void> invite(String competitionId, String email) =>
      _inner.invite(competitionId, email);
  @override
  Future<List<Profile>> listShooters() => _inner.listShooters();
  @override
  Future<List<CompetitionInvitation>> listMyInvitations() =>
      _inner.listMyInvitations();
  @override
  Future<List<String>> pendingInviteeIds(String competitionId) =>
      _inner.pendingInviteeIds(competitionId);
  @override
  Future<void> acceptInvitation(String competitionId) =>
      _inner.acceptInvitation(competitionId);
  @override
  Future<String?> joinToken(String competitionId) =>
      _inner.joinToken(competitionId);
  @override
  Future<void> joinByLink(String competitionId, String token) =>
      _inner.joinByLink(competitionId, token);
  @override
  Future<String> regenerateJoinToken(String competitionId) =>
      _inner.regenerateJoinToken(competitionId);
  @override
  Future<List<CompetitionMember>> membersOf(String competitionId) =>
      _inner.membersOf(competitionId);
  @override
  Future<void> submitResult(CompetitionResult result) =>
      _inner.submitResult(result);
  @override
  Future<List<CompetitionResult>> resultsOf(String competitionId) =>
      _inner.resultsOf(competitionId);
  @override
  Stream<List<CompetitionResult>> watchResults(String competitionId) =>
      _inner.watchResults(competitionId);
  @override
  Future<void> postMessage(CompetitionMessage message) =>
      _inner.postMessage(message);
  @override
  Stream<List<CompetitionMessage>> watchMessages(String competitionId) =>
      _inner.watchMessages(competitionId);
  @override
  Future<void> deleteMessage(String messageId) =>
      _inner.deleteMessage(messageId);
  @override
  Future<void> editMessage(String messageId, {required String body}) =>
      _inner.editMessage(messageId, body: body);
  @override
  Future<void> toggleReaction(String messageId, String emoji) =>
      _inner.toggleReaction(messageId, emoji);
  @override
  Future<String> uploadChatImage(
    String competitionId,
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) => _inner.uploadChatImage(
    competitionId,
    bytes,
    fileExtension: fileExtension,
  );
}

CompetitionResult _res(
  String id, {
  required String user,
  required int total,
}) => CompetitionResult(
  id: id,
  competitionId: 'c1',
  userId: user,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 600,
  innerTens: 0,
  payload: const <String, dynamic>{},
);

/// A result carrying a **real** session payload (every series shot centre), so
/// its scorecard can be rebuilt — for the view-another-shooter test (0037).
CompetitionResult _realResult(String id, {required String user}) {
  const program = ProgramCatalogue.airPistol10m;
  var session = Session.start(program);
  for (final stage in program.stages) {
    for (var s = 0; s < stage.seriesCount; s++) {
      var series = session.newSeries()!;
      for (var shot = 0; shot < stage.shotsPerSeries; shot++) {
        series = series.placeShot(const Shot(dxMm: 0, dyMm: 0));
      }
      session = session.sealSeries(series);
    }
  }
  final record = SessionRecord.fromSession(
    session,
    const ScoringService().scoreSession(session),
    id: id,
  );
  return CompetitionResult.fromSessionRecord(
    record,
    competitionId: 'c1',
    userId: user,
  );
}
