// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';

/// Runs the app with [authRepository] wired in.
///
/// `main()` passes the real Supabase repository; tests and the integration
/// harness pass a fake, so the app boots without touching real credentials.
void runTreffpunkt(AuthRepository authRepository) {
  runApp(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      child: const TreffpunktApp(),
    ),
  );
}
