// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// The auth-state stream contract that the UI relies on (spec 0003). The
// provider -> UI wiring is covered by the AuthGate widget and system tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';

import '../fake_auth_repository.dart';

void main() {
  test('emits the current status first (signed out by default)', () async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    expect(await fake.authStateChanges().first, isA<SignedOut>());
  });

  test(
    'is seeded from the current status (signed in, no sign-in flash)',
    () async {
      final fake = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'x', email: 'x@y.no')),
      );
      addTearDown(fake.dispose);
      expect(await fake.authStateChanges().first, isA<SignedIn>());
    },
  );
}
