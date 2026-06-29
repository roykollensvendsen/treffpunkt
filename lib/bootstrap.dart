// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/app.dart';
import 'package:treffpunkt/core/platform/browser_environment.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/presentation/forum_providers.dart';
import 'package:treffpunkt/features/scoring/data/contribution_service.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/data/target_scanner.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/settings/data/contribution_consent_store.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';
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
/// real Supabase for uploads (spec 0024). [imageSourceService] is the camera /
/// gallery for the "Skann skive" scan (spec 0039): `main()` passes the
/// `image_picker`-backed one; omitting it keeps the always-unavailable default,
/// so tests and the integration harness never touch a real camera.
/// [targetScanner] auto-detects holes in a scanned photo (spec 0040): `main()`
/// passes the `image`-backed one; omitting it keeps the always-unavailable
/// default, so tests never decode an image. [contributionService] uploads
/// consented training samples (spec 0041): `main()` passes the Supabase-backed
/// one; omitting it keeps the no-op default, so tests never reach a backend.
///
/// [initialWeapons] seeds the personal-weapons list at launch — `main()` loads
/// it from the [weaponStore] before this call so the notifier starts populated
/// without an async `build` (spec 0019). Omitting it starts with no weapons.
///
/// [pendingUploadsStore] is the durable upload queue's storage (spec 0025):
/// `main()` passes the `shared_preferences`-backed store so completed sessions
/// survive a restart and upload later; omitting it keeps the in-memory default,
/// so tests and the integration harness never touch real storage.
///
/// [themeModeStore] persists the chosen theme (spec 0030) and
/// [initialThemeMode] seeds it at launch — `main()` loads the saved choice from
/// the store before this call so the app starts on the right theme without a
/// first-frame flash. Omitting them follows the system/browser theme, so tests
/// and the integration harness never touch real storage.
///
/// [competitionRepository] backs the competitions feature (spec 0010): `main()`
/// passes the Supabase-backed one; omitting it keeps the in-memory default, so
/// tests and the integration harness never reach real Supabase.
void runTreffpunkt(
  AuthRepository authRepository, {
  SessionStore? sessionStore,
  SessionRepository? sessionRepository,
  PendingUploadsStore? pendingUploadsStore,
  WeaponStore? weaponStore,
  List<Weapon>? initialWeapons,
  LocationService? locationService,
  ImageSourceService? imageSourceService,
  TargetScanner? targetScanner,
  ContributionService? contributionService,
  ThemeModeStore? themeModeStore,
  ThemeMode? initialThemeMode,
  ContributionConsentStore? contributionConsentStore,
  bool? initialContributionEnabled,
  bool? initialDisclosureShown,
  CompetitionRepository? competitionRepository,
  ForumRepository? forumRepository,
  BrowserEnvironment? browserEnvironment,
  Sharer? sharer,
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
        if (imageSourceService != null)
          imageSourceServiceProvider.overrideWithValue(imageSourceService),
        if (targetScanner != null)
          targetScannerProvider.overrideWithValue(targetScanner),
        if (contributionService != null)
          contributionServiceProvider.overrideWithValue(contributionService),
        if (themeModeStore != null)
          themeModeStoreProvider.overrideWithValue(themeModeStore),
        if (initialThemeMode != null)
          initialThemeModeProvider.overrideWithValue(initialThemeMode),
        if (contributionConsentStore != null)
          contributionConsentStoreProvider.overrideWithValue(
            contributionConsentStore,
          ),
        if (initialContributionEnabled != null)
          initialContributionEnabledProvider.overrideWithValue(
            initialContributionEnabled,
          ),
        if (initialDisclosureShown != null)
          initialDisclosureShownProvider.overrideWithValue(
            initialDisclosureShown,
          ),
        if (competitionRepository != null)
          competitionRepositoryProvider.overrideWithValue(
            competitionRepository,
          ),
        if (forumRepository != null)
          forumRepositoryProvider.overrideWithValue(forumRepository),
        if (browserEnvironment != null)
          browserEnvironmentProvider.overrideWithValue(browserEnvironment),
        if (sharer != null) sharerProvider.overrideWithValue(sharer),
      ],
      child: const TreffpunktApp(),
    ),
  );
}
