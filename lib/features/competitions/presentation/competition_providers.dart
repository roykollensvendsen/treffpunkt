// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

/// The app's [CompetitionRepository] (spec 0010).
///
/// Defaults to an in-memory repository so tests and a fresh app never touch
/// real storage; `main()` overrides it with the Supabase-backed one.
final competitionRepositoryProvider = Provider<CompetitionRepository>(
  (ref) => InMemoryCompetitionRepository(),
);

/// Keeps the signed-in user's profile up to date (spec 0010): on each
/// transition to signed-in it upserts their profile, so a shared scoreboard can
/// show their name. Best-effort — a failure (e.g. the `profiles` table not yet
/// applied to hosted) is swallowed so it can never break sign-in.
///
/// Built eagerly at the app root (like the upload queue) so the listener is
/// registered at start; `fireImmediately` covers the already-signed-in case.
class ProfileSyncNotifier extends Notifier<void> {
  @override
  void build() {
    ref.listen(authStateChangesProvider, (previous, next) {
      final status = next.value;
      if (status is! SignedIn) return;
      final profile = Profile.fromAppUser(status.user);
      unawaited(
        ref
            .read(competitionRepositoryProvider)
            .upsertOwnProfile(profile)
            .catchError((Object error, StackTrace stackTrace) {
              // Defence in depth — a conforming repository already swallows,
              // but a failed profile sync must never surface on sign-in.
              if (!kReleaseMode) {
                debugPrint('Failed to sync the profile on sign-in: $error');
              }
            }),
      );
    }, fireImmediately: true);
  }
}

/// Drives the on-sign-in profile upsert; watched at the app root to stay alive.
final profileSyncProvider = NotifierProvider<ProfileSyncNotifier, void>(
  ProfileSyncNotifier.new,
);
