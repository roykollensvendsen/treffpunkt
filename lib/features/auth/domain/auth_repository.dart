// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/auth/domain/auth_status.dart';

/// Authentication operations, independent of any backend or platform.
///
/// Both the real Supabase implementation and the test fake implement this, so
/// the rest of the app never depends on Supabase or Google directly.
abstract interface class AuthRepository {
  /// Emits the current [AuthStatus] immediately, then every change.
  Stream<AuthStatus> authStateChanges();

  /// The current status, available synchronously (used to seed the stream).
  AuthStatus get currentStatus;

  /// Starts Google sign-in. The result arrives via [authStateChanges].
  Future<void> signInWithGoogle();

  /// Signs the current user out.
  Future<void> signOut();
}
