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
import 'package:treffpunkt/features/scoring/data/session_store.dart';

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
  runTreffpunkt(
    SupabaseAuthRepository(Supabase.instance.client.auth),
    sessionStore: SharedPreferencesSessionStore(prefs),
    locationService: const GeolocatorLocationService(),
  );
}
