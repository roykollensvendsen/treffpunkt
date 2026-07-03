// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/bootstrap.dart';
import 'package:treffpunkt/config/app_config.dart';
import 'package:treffpunkt/core/platform/browser_environment.dart';
import 'package:treffpunkt/core/platform/share_plus_sharer.dart';
import 'package:treffpunkt/features/auth/data/supabase_auth_repository.dart';
import 'package:treffpunkt/features/backup/data/backup_file_source.dart';
import 'package:treffpunkt/features/competitions/data/supabase_competition_repository.dart';
import 'package:treffpunkt/features/felt/data/felt_group_store.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/data/supabase_felt_session_repository.dart';
import 'package:treffpunkt/features/forum/data/supabase_forum_repository.dart';
import 'package:treffpunkt/features/notifications/data/supabase_notifications_repository.dart';
import 'package:treffpunkt/features/notifications/data/supabase_push_subscription_repository.dart';
import 'package:treffpunkt/features/scoring/data/big_data_cloud_geocoder.dart';
import 'package:treffpunkt/features/scoring/data/decimal_entry_store.dart';
import 'package:treffpunkt/features/scoring/data/geolocator_location_service.dart';
import 'package:treffpunkt/features/scoring/data/image_picker_image_source_service.dart';
import 'package:treffpunkt/features/scoring/data/image_target_scanner.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/personal_records_store.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/data/supabase_contribution_service.dart';
import 'package:treffpunkt/features/scoring/data/supabase_session_repository.dart';
import 'package:treffpunkt/features/settings/data/contribution_consent_store.dart';
import 'package:treffpunkt/features/settings/data/default_place_store.dart';
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
  final feltGroupStore = SharedPreferencesFeltGroupStore(prefs);
  final initialFeltGroup = await feltGroupStore.load();
  final defaultPlaceStore = SharedPreferencesDefaultPlaceStore(prefs);
  final initialDefaultPlace = await defaultPlaceStore.load();
  final personalRecordsStore = SharedPreferencesPersonalRecordsStore(prefs);
  final initialPersonalRecords = await personalRecordsStore.load();
  final decimalEntryStore = SharedPreferencesDecimalEntryStore(prefs);
  final initialDecimalEntry = await decimalEntryStore.load() ?? false;
  // Load the saved theme once here too, so the app starts on the right theme
  // without a first-frame flash of the wrong one (spec 0030).
  final initialThemeMode = await themeModeStore.load();
  final contributionConsentStore = SharedPreferencesContributionConsentStore(
    prefs,
  );
  // Load the consent flags once here so the notifier starts correct and the
  // one-time disclosure fires on the right run (spec 0041).
  final initialContributionEnabled = await contributionConsentStore
      .loadEnabled();
  final initialDisclosureShown = await contributionConsentStore
      .loadDisclosureShown();
  runTreffpunkt(
    SupabaseAuthRepository(Supabase.instance.client),
    sessionStore: SharedPreferencesSessionStore(prefs),
    feltSessionStore: SharedPreferencesFeltSessionStore(prefs),
    feltHistoryStore: SharedPreferencesFeltHistoryStore(prefs),
    feltSessionRepository: SupabaseFeltSessionRepository(
      Supabase.instance.client,
    ),
    sessionRepository: SupabaseSessionRepository(Supabase.instance.client),
    pendingUploadsStore: SharedPreferencesPendingUploadsStore(prefs),
    weaponStore: weaponStore,
    initialWeapons: savedWeapons,
    locationService: const GeolocatorLocationService(),
    geocoder: BigDataCloudGeocoder(http.Client()),
    imageSourceService: ImagePickerImageSourceService(),
    targetScanner: const ImageTargetScanner(),
    contributionService: SupabaseContributionService(Supabase.instance.client),
    feltGroupStore: feltGroupStore,
    initialFeltGroup: initialFeltGroup,
    backupFileSource: const FilePickerBackupFileSource(),
    defaultPlaceStore: defaultPlaceStore,
    initialDefaultPlace: initialDefaultPlace,
    personalRecordsStore: personalRecordsStore,
    initialPersonalRecords: initialPersonalRecords,
    decimalEntryStore: decimalEntryStore,
    initialDecimalEntry: initialDecimalEntry,
    themeModeStore: themeModeStore,
    initialThemeMode: initialThemeMode,
    contributionConsentStore: contributionConsentStore,
    initialContributionEnabled: initialContributionEnabled,
    initialDisclosureShown: initialDisclosureShown,
    competitionRepository: SupabaseCompetitionRepository(
      Supabase.instance.client,
    ),
    forumRepository: SupabaseForumRepository(Supabase.instance.client),
    notificationsRepository: SupabaseNotificationsRepository(
      Supabase.instance.client,
    ),
    pushSubscriptionRepository: SupabasePushSubscriptionRepository(
      Supabase.instance.client,
    ),
    browserEnvironment: readBrowserEnvironment(),
    sharer: const SharePlusSharer(),
  );
}
