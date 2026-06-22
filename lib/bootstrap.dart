// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Runs the app with [authRepository] and optional [sessionStore] wired in.
///
/// `main()` passes the real Supabase repository and the
/// `shared_preferences`-backed store; tests and the integration harness pass
/// fakes, so the app boots without touching real credentials or storage. When
/// no [sessionStore] is given the in-memory default is used.
void runTreffpunkt(
  AuthRepository authRepository, {
  SessionStore? sessionStore,
}) {
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        if (sessionStore != null)
          sessionStoreProvider.overrideWithValue(sessionStore),
      ],
      child: const TreffpunktApp(),
    ),
  );
}
