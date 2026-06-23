// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// App-tree tests for the durable upload queue's eager wiring (spec 0025): the
// queue must be built once, early, and stay alive for the whole app session, so
// a session finished offline last run uploads on the next plain restart (with
// no new completion) and a sign-in transition while merely browsing flushes it.
//
// These mount the REAL app tree (TreffpunktApp under a ProviderScope, the same
// overrides runTreffpunkt applies) and assert on the repository's uploads —
// they never read uploadQueueProvider directly, so they rely on the app's own
// eager wiring. They would FAIL before TreffpunktApp watched the queue: nothing
// else builds it without a completion.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

import '../../auth/fake_auth_repository.dart';

SessionRecord _record(String id, {int total = 50}) => SessionRecord(
  id: id,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 100,
  innerTens: 0,
  payload: <String, dynamic>{'id': id},
);

/// Mounts the real app tree with [authRepository], the fake [repository] and a
/// pre-seeded [pendingStore], exactly as `runTreffpunkt` wires it.
Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository authRepository,
  required SessionRepository repository,
  required PendingUploadsStore pendingStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        sessionRepositoryProvider.overrideWithValue(repository),
        pendingUploadsStoreProvider.overrideWithValue(pendingStore),
      ],
      child: const TreffpunktApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a pending record uploads on app start when signed in, with no new '
    'completion',
    (tester) async {
      final repository = InMemorySessionRepository();
      // The store already holds a completed record, as if persisted last run.
      final pendingStore = InMemoryPendingUploadsStore();
      await pendingStore.save(<SessionRecord>[_record('startup-1', total: 95)]);
      final authRepository = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'u1', email: 'a@b.no')),
      );
      addTearDown(authRepository.dispose);

      // Mount the real app and just let it settle — no session is completed.
      await _pumpApp(
        tester,
        authRepository: authRepository,
        repository: repository,
        pendingStore: pendingStore,
      );

      // The app's eager wiring built the queue, which loaded and flushed it.
      expect(repository.uploads.map((r) => r.id), <String>['startup-1']);
      expect(repository.uploads.single.total, 95);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  testWidgets(
    'a pending record stays queued while signed out, then uploads on sign-in '
    'while merely browsing',
    (tester) async {
      final repository = InMemorySessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      await pendingStore.save(<SessionRecord>[_record('signin-1', total: 88)]);
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);

      // Start signed OUT: the queue builds at app start but flush no-ops.
      await _pumpApp(
        tester,
        authRepository: authRepository,
        repository: repository,
        pendingStore: pendingStore,
      );
      expect(repository.uploads, isEmpty);
      expect((await pendingStore.load()).map((r) => r.id), <String>[
        'signin-1',
      ]);

      // Sign in while the user is just on the sign-in screen — the queue's
      // own listener (registered eagerly, not via a completion) flushes it.
      authRepository.emit(const SignedIn(AppUser(id: 'u1', email: 'a@b.no')));
      await tester.pumpAndSettle();

      expect(repository.uploads.map((r) => r.id), <String>['signin-1']);
      expect(repository.uploads.single.total, 88);
      expect(await pendingStore.load(), isEmpty);
    },
  );
}
