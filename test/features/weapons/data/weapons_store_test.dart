// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the in-memory personal-weapons store and the selected-weapon
// provider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

const WeaponClass _smallbore = WeaponClass(
  discipline: Discipline.pistol,
  caliberLabel: '.22 LR',
  label: '.22 LR',
);

Weapon _weapon(String id) => Weapon.fromClass(_smallbore, id: id, name: id);

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('the store starts empty', () {
    expect(container.read(weaponsProvider), isEmpty);
  });

  test('add appends a weapon', () {
    container.read(weaponsProvider.notifier).add(_weapon('a'));
    container.read(weaponsProvider.notifier).add(_weapon('b'));
    expect(container.read(weaponsProvider), [_weapon('a'), _weapon('b')]);
  });

  test('remove drops the weapon with the given id', () {
    container.read(weaponsProvider.notifier)
      ..add(_weapon('a'))
      ..add(_weapon('b'))
      ..remove('a');
    expect(container.read(weaponsProvider), [_weapon('b')]);
  });

  test('selectedWeaponProvider defaults to null and holds a selection', () {
    expect(container.read(selectedWeaponProvider), isNull);
    container.read(selectedWeaponProvider.notifier).select(_weapon('a'));
    expect(container.read(selectedWeaponProvider), _weapon('a'));
  });

  test('clear resets the selection back to null', () {
    container.read(selectedWeaponProvider.notifier).select(_weapon('a'));
    expect(container.read(selectedWeaponProvider), _weapon('a'));
    container.read(selectedWeaponProvider.notifier).clear();
    expect(container.read(selectedWeaponProvider), isNull);
  });
}
