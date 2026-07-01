// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/auth/presentation/sign_in_screen.dart';

/// Shows the sign-in screen when signed out, or [signedInBuilder]'s content
/// when signed in.
class AuthGate extends ConsumerWidget {
  /// Creates an auth gate that builds signed-in content with [signedInBuilder].
  const AuthGate({required this.signedInBuilder, super.key});

  /// Builds the content shown to a signed-in [AppUser].
  final Widget Function(AppUser user) signedInBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On sign-out, drop any screens pushed on top (e.g. Innstillinger) so the
    // user lands on the sign-in screen — rebuilt below as the home route —
    // instead of an orphaned screen left covering it (spec 0072).
    ref.listen(authStateChangesProvider, (previous, next) {
      if (previous?.value is SignedIn && next.value is SignedOut) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return ref
        .watch(authStateChangesProvider)
        .when(
          data: (status) => switch (status) {
            SignedOut() => const SignInScreen(),
            SignedIn(:final user) => signedInBuilder(user),
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Something went wrong: $error')),
          ),
        );
  }
}
