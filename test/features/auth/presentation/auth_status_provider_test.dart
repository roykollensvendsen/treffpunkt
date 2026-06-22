// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the auth-status Notifier: it seeds the current status, updates on
// new events, and treats stream errors as signed-out (spec 0003).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';

import '../fake_auth_repository.dart';

void main() {
  ProviderContainer containerFor(FakeAuthRepository fake) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return container;
  }

  test('seeds immediately with the current status (no loading flash)', () {
    final fake = FakeAuthRepository(
      initial: const SignedIn(AppUser(id: 'x', email: 'x@y.no')),
    );
    final container = containerFor(fake);

    final status = container.read(authStateChangesProvider);
    expect(status.isLoading, isFalse);
    expect(status.value, isA<SignedIn>());
  });

  test('updates when the repository emits a new status', () async {
    final fake = FakeAuthRepository();
    final container = containerFor(fake)
      ..listen(authStateChangesProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(authStateChangesProvider).value, isA<SignedOut>());

    fake.emit(const SignedIn(AppUser(id: 't', email: 'a@b.no')));
    await pumpEventQueue();
    expect(container.read(authStateChangesProvider).value, isA<SignedIn>());
  });

  test('falls back to signed out on an auth-stream error', () async {
    final fake = FakeAuthRepository(
      initial: const SignedIn(AppUser(id: 'x', email: 'x@y.no')),
    );
    final container = containerFor(fake)
      ..listen(authStateChangesProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(authStateChangesProvider).value, isA<SignedIn>());

    fake.emitError(Exception('stale OAuth code'));
    await pumpEventQueue();
    expect(container.read(authStateChangesProvider).value, isA<SignedOut>());
  });
}
