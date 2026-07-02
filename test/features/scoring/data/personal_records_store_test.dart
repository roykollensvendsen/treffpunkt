// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the personal-records store (spec 0102).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/data/personal_records_store.dart';

void main() {
  test('round-trips the records through shared_preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesPersonalRecordsStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.load(), isEmpty);
    await store.save(const {
      '10 m Luftpistol 60 skudd': (points: 372, inner: 11),
      'NorgesFelt-løype 2026 · Gruppe 2': (points: 58, inner: 6),
    });
    final loaded = await store.load();
    expect(loaded['10 m Luftpistol 60 skudd'], (points: 372, inner: 11));
    expect(
      loaded['NorgesFelt-løype 2026 · Gruppe 2'],
      (points: 58, inner: 6),
    );
  });

  test('saving an empty map clears earlier baselines', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesPersonalRecordsStore(
      await SharedPreferences.getInstance(),
    );
    await store.save(const {'X': (points: 1, inner: 0)});
    await store.save(const {});
    expect(await store.load(), isEmpty);
  });

  test('malformed stored JSON loads as empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'personal_records': '{"X": "not-a-record"}',
    });
    final store = SharedPreferencesPersonalRecordsStore(
      await SharedPreferences.getInstance(),
    );
    expect(await store.load(), isEmpty);
  });
}
