// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';

/// In-memory [AuthRepository] for tests — no Supabase and no Google.
class FakeAuthRepository implements AuthRepository {
  /// Creates a fake starting at [initial] (signed out by default).
  FakeAuthRepository({AuthStatus initial = const SignedOut()})
    : _current = initial;

  final StreamController<AuthStatus> _controller =
      StreamController<AuthStatus>.broadcast();
  AuthStatus _current;

  /// If true, the next [signInWithGoogle] throws instead of signing in.
  bool failNextSignIn = false;

  /// Optional delay before [signInWithGoogle] resolves (to observe loading).
  Duration signInDelay = Duration.zero;

  /// Number of times [signInWithGoogle] has been called.
  int signInCallCount = 0;

  /// Number of times [signOut] has been called.
  int signOutCallCount = 0;

  @override
  AuthStatus get currentStatus => _current;

  @override
  Stream<AuthStatus> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    signInCallCount++;
    if (signInDelay > Duration.zero) {
      await Future<void>.delayed(signInDelay);
    }
    if (failNextSignIn) {
      failNextSignIn = false;
      throw Exception('sign-in failed');
    }
    emit(const SignedIn(AppUser(id: 'fake-user', email: 'shooter@example.no')));
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    emit(const SignedOut());
  }

  /// Emits [status] as the new current status.
  void emit(AuthStatus status) {
    _current = status;
    _controller.add(status);
  }

  /// Emits [error] on the auth stream (e.g. to simulate a failed sign-in).
  void emitError(Object error) => _controller.addError(error);

  /// Closes the underlying stream controller.
  void dispose() => _controller.close();
}
