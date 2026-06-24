// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/data/contribution_consent_store.dart';

/// The app's [ContributionConsentStore] (spec 0041).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store.
final contributionConsentStoreProvider = Provider<ContributionConsentStore>(
  (ref) => InMemoryContributionConsentStore(),
);

/// Whether contribution is enabled, loaded at launch (opt-out default `true`).
///
/// `main()` reads the saved flag once and overrides this so the notifier starts
/// correct without an async `build`.
final initialContributionEnabledProvider = Provider<bool>((ref) => true);

/// Whether the one-time disclosure has been shown, loaded at launch (`false`).
final initialDisclosureShownProvider = Provider<bool>((ref) => false);

/// The shooter's training-data contribution consent (spec 0041): whether it is
/// [enabled] and whether the one-time [disclosureShown] has been displayed.
@immutable
class ContributionConsent {
  /// Creates a consent state.
  const ContributionConsent({
    required this.enabled,
    required this.disclosureShown,
  });

  /// Whether the shooter contributes scans (opt-out, defaults on).
  final bool enabled;

  /// Whether the one-time disclosure has been shown.
  final bool disclosureShown;

  /// A copy with the given fields replaced.
  ContributionConsent copyWith({bool? enabled, bool? disclosureShown}) =>
      ContributionConsent(
        enabled: enabled ?? this.enabled,
        disclosureShown: disclosureShown ?? this.disclosureShown,
      );
}

/// Holds and persists the contribution consent (spec 0041).
///
/// Seeds from the launch-loaded providers; [setEnabled] and
/// [markDisclosureShown] update state immediately and persist best-effort (a
/// failed write only logs in debug builds, never breaks the UI), mirroring
/// `ThemeModeNotifier`.
class ContributionConsentNotifier extends Notifier<ContributionConsent> {
  @override
  ContributionConsent build() => ContributionConsent(
    enabled: ref.read(initialContributionEnabledProvider),
    disclosureShown: ref.read(initialDisclosureShownProvider),
  );

  /// Turns contribution on or off and persists the choice.
  void setEnabled({required bool enabled}) {
    state = state.copyWith(enabled: enabled);
    _persist(
      ref.read(contributionConsentStoreProvider).saveEnabled(enabled: enabled),
    );
  }

  /// Records that the one-time disclosure has been shown (idempotent).
  void markDisclosureShown() {
    if (state.disclosureShown) return;
    state = state.copyWith(disclosureShown: true);
    _persist(ref.read(contributionConsentStoreProvider).markDisclosureShown());
  }

  void _persist(Future<void> write) {
    unawaited(
      write.catchError((Object error, StackTrace stackTrace) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist contribution consent: $error');
        }
      }),
    );
  }
}

/// The shooter's contribution consent (spec 0041).
final contributionConsentProvider =
    NotifierProvider<ContributionConsentNotifier, ContributionConsent>(
      ContributionConsentNotifier.new,
    );
