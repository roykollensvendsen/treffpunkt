// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/browser_environment.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';

/// Provides the app's [AuthRepository].
///
/// The default body throws: `main()` (and every test) must override this with a
/// real or fake repository, so a forgotten override fails loudly instead of
/// silently hitting the network.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('authRepositoryProvider must be overridden'),
);

/// Holds the current [AuthStatus] (the authoritative signed-in/out truth).
///
/// Seeds with the repository's current status so the UI always has a value
/// immediately (no loading flash), then updates as the auth stream emits. Using
/// a [Notifier] with a single subscription avoids a StreamProvider re-subscribe
/// loop when the auth stream stays pending.
class AuthStatusNotifier extends Notifier<AsyncValue<AuthStatus>> {
  @override
  AsyncValue<AuthStatus> build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.authStateChanges().listen(
      (status) => state = AsyncData(status),
      // An auth-stream error (e.g. a stale OAuth code) just means "not signed
      // in"; fall back to the sign-in screen so the user can retry.
      onError: (Object _, StackTrace _) =>
          state = const AsyncData<AuthStatus>(SignedOut()),
    );
    ref.onDispose(subscription.cancel);
    return AsyncData(repository.currentStatus);
  }
}

/// The browser context the app runs in (spec 0042).
///
/// Defaults to the empty environment so tests and non-web platforms never warn;
/// `main()` overrides it with the real read so the sign-in screen can detect an
/// in-app / standalone webview (where Google blocks OAuth) and guide the user to
/// a real browser.
final browserEnvironmentProvider = Provider<BrowserEnvironment>(
  (ref) => const BrowserEnvironment.empty(),
);

/// The current authentication status as an [AsyncValue].
final authStateChangesProvider =
    NotifierProvider<AuthStatusNotifier, AsyncValue<AuthStatus>>(
      AuthStatusNotifier.new,
    );

/// Holds the loading/error state of the current sign-in or sign-out action.
///
/// The authoritative status lives on [authStateChangesProvider]; this only
/// drives the button spinner and error feedback.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Starts Google sign-in, tracking loading and surfacing any error.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(authRepositoryProvider).signInWithGoogle,
    );
  }

  /// Signs out, tracking loading and surfacing any error.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ref.read(authRepositoryProvider).signOut);
  }

  /// Deletes the signed-in user's account (spec 0126) and signs out.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(authRepositoryProvider).deleteAccount,
    );
  }
}

/// The [AuthController] provider.
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
