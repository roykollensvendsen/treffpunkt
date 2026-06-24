// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the contribution consent store (spec 0041): opt-out defaults
// (enabled=true, disclosure not shown) and a round-trip through both stores.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/settings/data/contribution_consent_store.dart';

void main() {
  test(
    'in-memory store defaults to enabled and disclosure not shown',
    () async {
      final store = InMemoryContributionConsentStore();
      expect(await store.loadEnabled(), isTrue);
      expect(await store.loadDisclosureShown(), isFalse);
    },
  );

  test('in-memory store round-trips both flags', () async {
    final store = InMemoryContributionConsentStore();
    await store.saveEnabled(enabled: false);
    await store.markDisclosureShown();
    expect(await store.loadEnabled(), isFalse);
    expect(await store.loadDisclosureShown(), isTrue);
  });

  test('shared-preferences store defaults to opt-out enabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesContributionConsentStore(prefs);

    expect(await store.loadEnabled(), isTrue);
    expect(await store.loadDisclosureShown(), isFalse);
  });

  test('shared-preferences store persists the flags', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesContributionConsentStore(prefs);

    await store.saveEnabled(enabled: false);
    await store.markDisclosureShown();

    final reloaded = SharedPreferencesContributionConsentStore(prefs);
    expect(await reloaded.loadEnabled(), isFalse);
    expect(await reloaded.loadDisclosureShown(), isTrue);
  });
}
