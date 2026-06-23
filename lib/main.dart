// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/bootstrap.dart';
import 'package:treffpunkt/config/app_config.dart';
import 'package:treffpunkt/features/auth/data/supabase_auth_repository.dart';
import 'package:treffpunkt/features/scoring/data/geolocator_location_service.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/data/supabase_session_repository.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';
import 'package:treffpunkt/features/weapons/data/weapon_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
    // Implicit flow returns the session in the redirect URL fragment, which is
    // reliable for web OAuth; PKCE's code+verifier exchange is brittle on web.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  final weaponStore = SharedPreferencesWeaponStore(prefs);
  // Load the saved weapons once here (prefs is already awaited) so the notifier
  // can start populated without an async build (spec 0019).
  final savedWeapons = await weaponStore.load();
  final themeModeStore = SharedPreferencesThemeModeStore(prefs);
  // Load the saved theme once here too, so the app starts on the right theme
  // without a first-frame flash of the wrong one (spec 0030).
  final initialThemeMode = await themeModeStore.load();
  runTreffpunkt(
    SupabaseAuthRepository(Supabase.instance.client.auth),
    sessionStore: SharedPreferencesSessionStore(prefs),
    sessionRepository: SupabaseSessionRepository(Supabase.instance.client),
    pendingUploadsStore: SharedPreferencesPendingUploadsStore(prefs),
    weaponStore: weaponStore,
    initialWeapons: savedWeapons,
    locationService: const GeolocatorLocationService(),
    themeModeStore: themeModeStore,
    initialThemeMode: initialThemeMode,
  );
}
