// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/data/weapon_store.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Runs the app with [authRepository] and optional [sessionStore] /
/// [sessionRepository] / [weaponStore] / [locationService] wired in.
///
/// `main()` passes the real Supabase repositories, the
/// `shared_preferences`-backed stores and the `geolocator`-backed location
/// service; tests and the integration harness pass fakes (or omit them), so the
/// app boots without touching real credentials, storage or GPS. When no
/// [sessionStore], [sessionRepository] or [weaponStore] is given the in-memory
/// default is used; when no [locationService] is given the always-unavailable
/// default stays, so no test reaches real GPS (ADR-0015) — and no test reaches
/// real Supabase for uploads (spec 0024).
///
/// [initialWeapons] seeds the personal-weapons list at launch — `main()` loads
/// it from the [weaponStore] before this call so the notifier starts populated
/// without an async `build` (spec 0019). Omitting it starts with no weapons.
///
/// [pendingUploadsStore] is the durable upload queue's storage (spec 0025):
/// `main()` passes the `shared_preferences`-backed store so completed sessions
/// survive a restart and upload later; omitting it keeps the in-memory default,
/// so tests and the integration harness never touch real storage.
void runTreffpunkt(
  AuthRepository authRepository, {
  SessionStore? sessionStore,
  SessionRepository? sessionRepository,
  PendingUploadsStore? pendingUploadsStore,
  WeaponStore? weaponStore,
  List<Weapon>? initialWeapons,
  LocationService? locationService,
}) {
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        if (sessionStore != null)
          sessionStoreProvider.overrideWithValue(sessionStore),
        if (sessionRepository != null)
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
        if (pendingUploadsStore != null)
          pendingUploadsStoreProvider.overrideWithValue(pendingUploadsStore),
        if (weaponStore != null)
          weaponStoreProvider.overrideWithValue(weaponStore),
        if (initialWeapons != null)
          initialWeaponsProvider.overrideWithValue(initialWeapons),
        if (locationService != null)
          locationServiceProvider.overrideWithValue(locationService),
      ],
      child: const TreffpunktApp(),
    ),
  );
}
