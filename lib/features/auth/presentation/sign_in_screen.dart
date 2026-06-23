// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';

/// Key for the Google sign-in button (used by widget and system tests).
const Key signInWithGoogleButtonKey = ValueKey<String>(
  'signInWithGoogleButton',
);

/// Screen shown when no user is signed in.
class SignInScreen extends ConsumerWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authControllerProvider);
    final busy = action.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Treffpunkt', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: signInWithGoogleButtonKey,
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Sign-in failed. Please try again.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // A discreet build-version footer so a user can confirm which build
            // they are running, even before signing in (spec 0028).
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: BuildVersionLabel(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
