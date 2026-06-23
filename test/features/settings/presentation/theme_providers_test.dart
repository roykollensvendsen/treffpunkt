// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the theme-mode notifier (spec 0030): it seeds from the launch value
// and persists each selection through the store.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

void main() {
  test('defaults to system when no launch value is provided', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('seeds the initial state from the launch value', () {
    final container = ProviderContainer(
      overrides: [
        initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('select updates the state and persists the choice', () async {
    final store = InMemoryThemeModeStore();
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(themeModeProvider.notifier).select(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    // The choice reached the store, so it will survive a restart.
    expect(await store.load(), ThemeMode.dark);
  });
}
