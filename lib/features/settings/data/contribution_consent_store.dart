// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for the shooter's training-data contribution consent (0041).
///
/// The app depends on this interface, not a concrete engine (mirroring
/// `ThemeModeStore`), so the feature is testable without real storage. Two
/// flags survive a restart: whether contribution is **enabled** (opt-out, so it
/// defaults to `true`), and whether the one-time **disclosure** has been shown
/// (defaults to `false`).
abstract interface class ContributionConsentStore {
  /// Persists whether contribution is [enabled].
  Future<void> saveEnabled({required bool enabled});

  /// The saved enabled flag, or `true` (opt-out default) when none was saved.
  Future<bool> loadEnabled();

  /// Records that the one-time disclosure has been shown.
  Future<void> markDisclosureShown();

  /// Whether the disclosure has been shown, or `false` when never recorded.
  Future<bool> loadDisclosureShown();
}

/// A [ContributionConsentStore] that keeps the flags in memory only.
///
/// The default binding and the test fake: no platform I/O. A restart is
/// simulated in tests by reusing the same instance across a fresh notifier.
class InMemoryContributionConsentStore implements ContributionConsentStore {
  /// Creates an in-memory store (enabled by default, disclosure not shown).
  InMemoryContributionConsentStore();

  bool _enabled = true;
  bool _disclosureShown = false;

  @override
  Future<void> saveEnabled({required bool enabled}) async => _enabled = enabled;

  @override
  Future<bool> loadEnabled() async => _enabled;

  @override
  Future<void> markDisclosureShown() async => _disclosureShown = true;

  @override
  Future<bool> loadDisclosureShown() async => _disclosureShown;
}

/// A [ContributionConsentStore] backed by `shared_preferences` (web + mobile).
///
/// Stores the two booleans under [_enabledKey] / [_disclosureKey]. An absent
/// enabled flag loads as `true` (opt-out default); an absent disclosure flag as
/// `false`. Tests drive it with `SharedPreferences.setMockInitialValues`.
class SharedPreferencesContributionConsentStore
    implements ContributionConsentStore {
  /// Creates a store reading and writing through [_prefs].
  SharedPreferencesContributionConsentStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _enabledKey = 'contribution_enabled';
  static const String _disclosureKey = 'contribution_disclosure_shown';

  @override
  Future<void> saveEnabled({required bool enabled}) async {
    await _prefs.setBool(_enabledKey, enabled);
  }

  @override
  Future<bool> loadEnabled() async => _prefs.getBool(_enabledKey) ?? true;

  @override
  Future<void> markDisclosureShown() async {
    await _prefs.setBool(_disclosureKey, true);
  }

  @override
  Future<bool> loadDisclosureShown() async =>
      _prefs.getBool(_disclosureKey) ?? false;
}
