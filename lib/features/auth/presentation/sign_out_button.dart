// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';

/// Key for the sign-out action (used by tests).
const Key signOutButtonKey = ValueKey<String>('signOutButton');

/// An app-bar action that signs the current user out.
class SignOutButton extends ConsumerWidget {
  /// Creates a sign-out button.
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: signOutButtonKey,
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
    );
  }
}
