// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';
import 'package:treffpunkt/features/auth/presentation/auth_gate.dart';
import 'package:treffpunkt/features/auth/presentation/sign_out_button.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';
import 'package:treffpunkt/features/settings/presentation/theme_mode_button.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

/// The Treffpunkt application root: an auth gate in front of the app content.
class TreffpunktApp extends ConsumerWidget {
  /// Creates the application root.
  const TreffpunktApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the durable upload queue alive for the whole app session (spec
    // 0025). Watching it here — at the always-mounted root, never reading the
    // value — is what builds the notifier eagerly at app start, so its startup
    // load+flush runs and its sign-in listener is registered without waiting
    // for a session to complete. Without this the queue would only build on the
    // next completion, and a session finished offline last run would never
    // upload after a plain restart.
    ref.watch(uploadQueueProvider);
    return MaterialApp(
      title: 'Treffpunkt',
      theme: lightTheme,
      darkTheme: darkTheme,
      // Follow the system/browser theme by default; a saved choice (spec 0030)
      // overrides it to light or dark.
      themeMode: ref.watch(themeModeProvider),
      home: AuthGate(
        signedInBuilder: (user) => const ProgramPickerScreen(
          actions: [ThemeModeButton(), SignOutButton()],
        ),
      ),
    );
  }
}
