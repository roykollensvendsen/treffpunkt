// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the contribution consent notifier (spec 0041): it seeds from
// the launch-loaded providers and persists changes through the store.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/settings/data/contribution_consent_store.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';

void main() {
  test('seeds enabled and disclosure from the initial providers', () {
    final container = ProviderContainer(
      overrides: [
        initialContributionEnabledProvider.overrideWithValue(false),
        initialDisclosureShownProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    final consent = container.read(contributionConsentProvider);
    expect(consent.enabled, isFalse);
    expect(consent.disclosureShown, isTrue);
  });

  test('setEnabled flips the state and persists', () async {
    final store = InMemoryContributionConsentStore();
    final container = ProviderContainer(
      overrides: [
        contributionConsentStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(contributionConsentProvider.notifier)
        .setEnabled(enabled: false);

    expect(container.read(contributionConsentProvider).enabled, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(await store.loadEnabled(), isFalse);
  });

  test('markDisclosureShown sets and persists once', () async {
    final store = InMemoryContributionConsentStore();
    final container = ProviderContainer(
      overrides: [
        contributionConsentStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    container.read(contributionConsentProvider.notifier).markDisclosureShown();

    expect(
      container.read(contributionConsentProvider).disclosureShown,
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await store.loadDisclosureShown(), isTrue);
  });
}
