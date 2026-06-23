// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the theme-mode store (spec 0030): the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';

void main() {
  group('InMemoryThemeModeStore', () {
    test('defaults to system before any save', () async {
      expect(await InMemoryThemeModeStore().load(), ThemeMode.system);
    });

    test('saves then loads the same mode', () async {
      final store = InMemoryThemeModeStore();
      await store.save(ThemeMode.dark);
      expect(await store.load(), ThemeMode.dark);
    });
  });

  group('SharedPreferencesThemeModeStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Future<SharedPreferencesThemeModeStore> store() async =>
        SharedPreferencesThemeModeStore(await SharedPreferences.getInstance());

    test('defaults to system when nothing was saved', () async {
      expect(await (await store()).load(), ThemeMode.system);
    });

    test('round-trips each mode through real keys', () async {
      for (final mode in ThemeMode.values) {
        final s = await store();
        await s.save(mode);
        expect(await s.load(), mode);
      }
    });

    test('persists across a fresh store on the same storage', () async {
      await (await store()).save(ThemeMode.light);
      // A new instance over the same (mock) prefs simulates a restart.
      expect(await (await store()).load(), ThemeMode.light);
    });

    test('an unrecognised stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_mode': 'midnight',
      });
      expect(await (await store()).load(), ThemeMode.system);
    });
  });
}
