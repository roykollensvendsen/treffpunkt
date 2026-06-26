// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:uuid/uuid.dart';

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

/// Mints a client-side competition id (a uuid), overridable in tests for
/// deterministic ids (mirrors `sessionIdGeneratorProvider`).
final competitionIdGeneratorProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

/// The signed-in user's id, or `null` when signed out — used to stamp a new
/// competition's owner and to decide whether the viewer may invite (spec 0011).
final currentUserIdProvider = Provider<String?>((ref) {
  final status = ref.watch(authStateChangesProvider).value;
  return status is SignedIn ? status.user.id : null;
});

/// The competitions the signed-in user owns or has joined (spec 0011).
///
/// A foreground read: it surfaces [CompetitionSyncException] as the provider's
/// error so the screen can show a retry. Re-read by invalidating it when the
/// screen opens or after a create/accept.
final myCompetitionsProvider = FutureProvider<List<Competition>>(
  (ref) => ref.watch(competitionRepositoryProvider).listMine(),
);

/// The signed-in user's pending invitations, each with its competition attached
/// (spec 0011). Invalidated after accepting one.
final myInvitationsProvider = FutureProvider<List<CompetitionInvitation>>(
  (ref) => ref.watch(competitionRepositoryProvider).listMyInvitations(),
);

/// The registered shooters, for the invite picker (spec 0032). A foreground
/// read; the detail screen filters out the owner and current members before
/// showing them. Invalidated after inviting, so an invited shooter can be
/// dropped from a later view if desired.
final shootersProvider = FutureProvider<List<Profile>>(
  (ref) => ref.watch(competitionRepositoryProvider).listShooters(),
);

/// The participants of a competition, for its detail view (spec 0011).
// The family's concrete type (FutureProviderFamily) is not part of Riverpod's
// public API, so it cannot be annotated here; the generic arguments below pin
// the value and argument types.
// ignore: specify_nonobvious_property_types
final competitionMembersProvider =
    FutureProvider.family<List<CompetitionMember>, String>(
      (ref, competitionId) =>
          ref.watch(competitionRepositoryProvider).membersOf(competitionId),
    );

/// The user ids already invited (pending) to a competition, so the owner's
/// invite picker marks them "Invitert" across sessions (spec 0032). Owner-only
/// server-side; a non-owner reads an empty list. Invalidated after inviting.
// ignore: specify_nonobvious_property_types
final competitionInviteesProvider = FutureProvider.family<List<String>, String>(
  (ref, competitionId) =>
      ref.watch(competitionRepositoryProvider).pendingInviteeIds(competitionId),
);

/// The live scoreboard for a competition (spec 0013): its results, re-emitted
/// whenever a participant submits (Supabase Realtime). The screen ranks the
/// emitted results best-per-shooter for display.
// ignore: specify_nonobvious_property_types
final competitionScoreboardProvider =
    StreamProvider.family<List<CompetitionResult>, String>(
      (ref, competitionId) =>
          ref.watch(competitionRepositoryProvider).watchResults(competitionId),
    );
