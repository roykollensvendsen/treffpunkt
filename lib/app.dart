// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/auth/presentation/auth_gate.dart';
import 'package:treffpunkt/features/auth/presentation/sign_out_button.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';

/// The Treffpunkt application root: an auth gate in front of the app content.
class TreffpunktApp extends StatelessWidget {
  /// Creates the application root.
  const TreffpunktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treffpunkt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: AuthGate(
        signedInBuilder: (user) => const SeriesScreen(
          program: Program.airRifle10m,
          actions: [SignOutButton()],
        ),
      ),
    );
  }
}
