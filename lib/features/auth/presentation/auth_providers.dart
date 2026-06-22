// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Streams the current [AuthStatus] (the authoritative signed-in/out truth).
final authStateChangesProvider = StreamProvider<AuthStatus>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
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
}

/// The [AuthController] provider.
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
