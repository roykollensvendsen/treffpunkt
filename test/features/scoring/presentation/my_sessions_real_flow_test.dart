// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// High-fidelity flow test for "Mine økter" (spec 0026): it mounts the WHOLE app
// the way `main()` does (via `runTreffpunkt`, signed in, with in-memory fakes),
// then drives the REAL UI — picker → session setup → the guided series screen —
// to complete a whole session, and finally opens "Mine økter" from the picker's
// history button and asserts the finished session's row (program, score) shows
// with the "Ikke synkronisert" badge.
//
// This differs from `my_sessions_screen_test.dart`'s single-`ProviderContainer`
// test: here the completion runs inside `SeriesScreen`'s NESTED `ProviderScope`
// (the real app's structure), so the enqueue and the list's pending read happen
// in different scopes. It pins that the row still appears, regardless of any
// scope/instance discrepancy between the queue the enqueue updates and the one
// the list watches — the shared pending-uploads store is the durable source.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/bootstrap.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

import '../../auth/fake_auth_repository.dart';

void main() {
  testWidgets(
    'completing a real session through SeriesScreen shows it in Mine økter, '
    'still pending',
    (tester) async {
      // The smallest offered program — air pistol, six 10-shot series. We never
      // sign in to a real backend, so the completed session stays in the upload
      // queue (the flush no-ops) and shows with the "Ikke synkronisert" badge.
      const program = ProgramCatalogue.airPistol10m;

      // Wire the app exactly as `runTreffpunkt` does in `main()`, but with the
      // in-memory fakes: signed in, an in-memory session store, an in-memory
      // repository and an in-memory pending-uploads store (the durable outbox).
      final authRepository = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'u1', email: 'a@b.no')),
      );
      addTearDown(authRepository.dispose);
      final pendingStore = InMemoryPendingUploadsStore();

      runTreffpunkt(
        authRepository,
        sessionStore: InMemorySessionStore(),
        sessionRepository: _OfflineSessionRepository(),
        pendingUploadsStore: pendingStore,
      );
      await tester.pumpAndSettle();

      // The picker is shown. Pick the air-pistol program from the catalogue.
      expect(find.byKey(mySessionsButtonKey), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey<String>('program-${program.name}')),
      );
      await tester.pumpAndSettle();

      // Confirm the session setup (date/time + place), reaching the guided
      // series screen and its nested ProviderScope.
      await tester.tap(find.byKey(sessionConfirmKey));
      await tester.pumpAndSettle();
      expect(find.text('0 / 10'), findsOneWidget);

      // Shoot the whole session: place every shot of every series, sealing each
      // series, until the scorecard ("Session complete") appears.
      final stage = program.stages.single;
      for (var series = 0; series < stage.seriesCount; series++) {
        for (var shot = 0; shot < stage.shotsPerSeries; shot++) {
          await tester.tap(find.byKey(seriesTargetKey));
          await tester.pump();
        }
        // The series is full: seal it to advance (or complete the session).
        await tester.tap(find.byKey(sealSeriesKey));
        await tester.pumpAndSettle();
      }

      // Completion: the scorecard is shown — the session ran to its end through
      // SeriesScreen's nested scope, which is where the enqueue fires.
      expect(find.byKey(sessionCompleteKey), findsOneWidget);

      // Back to the picker, then open "Mine økter" via the history button.
      await tester.pageBack();
      await tester.pumpAndSettle();
      // SessionSetupScreen is still on the stack under the series screen.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(mySessionsButtonKey), findsOneWidget);

      await tester.tap(find.byKey(mySessionsButtonKey));
      await tester.pumpAndSettle();

      // The finished session is in the list — not the empty state. Its program,
      // its perfect score (60 centre shots → 600 / 600 with 60 inner tens), and
      // the pending badge because it has not synced to any account.
      expect(find.byKey(noSessionsKey), findsNothing);
      // Exactly one saved-session card (keyed by the recording's own id).
      expect(find.byKey(mySessionCard(_onlySessionId(tester))), findsOneWidget);
      expect(find.text('10 m Air Pistol'), findsOneWidget);
      expect(find.text('600 / 600 · 60×X'), findsOneWidget);
      expect(find.byKey(notSyncedBadgeKey), findsOneWidget);
      expect(find.text('Ikke synkronisert'), findsOneWidget);
    },
  );
}

/// The id of the single session shown in "Mine økter", read from the live
/// upload queue in the widget's own scope, so the card can be located by its
/// per-id key without knowing the generated UUID up front.
String _onlySessionId(WidgetTester tester) {
  final element = tester.element(find.byType(MySessionsScreen));
  final pending = ProviderScope.containerOf(
    element,
  ).read(uploadQueueProvider);
  expect(pending, hasLength(1));
  return pending.single.id;
}

/// A [SessionRepository] that never accepts an upload (so a completed session
/// stays pending) and never returns a synced one — the offline case behind the
/// "Ikke synkronisert" badge. Mirrors a real backend that is unreachable.
class _OfflineSessionRepository implements SessionRepository {
  @override
  Future<void> upload(SessionRecord record) async => throw Exception('offline');

  @override
  Future<List<SessionRecord>> list() async => const <SessionRecord>[];
  @override
  Future<void> deleteById(String id) async {}
}
