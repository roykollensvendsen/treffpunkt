// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the default-place store (spec 0102).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/settings/data/default_place_store.dart';

void main() {
  test('round-trips the place through shared_preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesDefaultPlaceStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.load(), isNull);
    await store.save('Løvenskioldbanen');
    expect(await store.load(), 'Løvenskioldbanen');
  });

  test('saving null or blank clears the value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesDefaultPlaceStore(
      await SharedPreferences.getInstance(),
    );

    await store.save('Banen');
    await store.save('   ');
    expect(await store.load(), isNull);
    await store.save('Banen');
    await store.save(null);
    expect(await store.load(), isNull);
  });

  test('the in-memory store behaves the same', () async {
    final store = InMemoryDefaultPlaceStore();
    expect(await store.load(), isNull);
    await store.save('  Banen  ');
    expect(await store.load(), 'Banen');
    await store.save('');
    expect(await store.load(), isNull);
  });
}
