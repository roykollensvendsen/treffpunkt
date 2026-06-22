// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Runs the app with [authRepository] and optional [sessionStore] /
/// [locationService] wired in.
///
/// `main()` passes the real Supabase repository, the
/// `shared_preferences`-backed store and the `geolocator`-backed location
/// service; tests and the integration harness pass fakes (or omit them), so the
/// app boots without touching real credentials, storage or GPS. When no
/// [sessionStore] is given the in-memory default is used; when no
/// [locationService] is given the always-unavailable default stays, so no test
/// reaches real GPS (ADR-0015).
void runTreffpunkt(
  AuthRepository authRepository, {
  SessionStore? sessionStore,
  LocationService? locationService,
}) {
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        if (sessionStore != null)
          sessionStoreProvider.overrideWithValue(sessionStore),
        if (locationService != null)
          locationServiceProvider.overrideWithValue(locationService),
      ],
      child: const TreffpunktApp(),
    ),
  );
}
