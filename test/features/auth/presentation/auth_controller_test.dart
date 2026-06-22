// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
  });

  AuthController controller() =>
      container.read(authControllerProvider.notifier);

  test('signInWithGoogle delegates and ends in data', () async {
    await controller().signInWithGoogle();
    expect(fake.signInCallCount, 1);
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
  });

  test('a failed sign-in surfaces an error', () async {
    fake.failNextSignIn = true;
    await controller().signInWithGoogle();
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('signOut delegates', () async {
    await controller().signOut();
    expect(fake.signOutCallCount, 1);
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
  });

  test('shows loading while a sign-in is in flight', () async {
    fake.signInDelay = const Duration(milliseconds: 50);
    final future = controller().signInWithGoogle();
    expect(container.read(authControllerProvider), isA<AsyncLoading<void>>());
    await future;
    expect(container.read(authControllerProvider), isA<AsyncData<void>>());
  });
}
