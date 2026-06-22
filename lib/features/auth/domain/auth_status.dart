// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/auth/domain/app_user.dart';

/// The authentication state of the app.
sealed class AuthStatus {
  /// Const base constructor.
  const AuthStatus();
}

/// No user is signed in.
final class SignedOut extends AuthStatus {
  /// Creates a signed-out status.
  const SignedOut();
}

/// A user is signed in.
final class SignedIn extends AuthStatus {
  /// Creates a signed-in status for [user].
  const SignedIn(this.user);

  /// The signed-in user.
  final AppUser user;
}
