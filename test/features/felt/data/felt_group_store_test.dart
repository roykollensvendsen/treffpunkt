// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the last-used felt-group store (spec 0099).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/data/felt_group_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

void main() {
  test(
    'round-trips the group through shared_preferences (spec 0099)',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPreferencesFeltGroupStore(
        await SharedPreferences.getInstance(),
      );

      expect(await store.load(), isNull);
      await store.save(FeltShooterGroup.two);
      expect(await store.load(), FeltShooterGroup.two);
    },
  );

  test('an unrecognised saved value loads as null (spec 0099)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'felt_group': 'gruppe99',
    });
    final store = SharedPreferencesFeltGroupStore(
      await SharedPreferences.getInstance(),
    );
    expect(await store.load(), isNull);
  });
}
