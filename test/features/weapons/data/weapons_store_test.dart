// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the personal-weapons notifier and the selected-weapon
// provider: starting empty, add/remove, persisting each change to the
// WeaponStore, and seeding a fresh notifier from the saved list (a restart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapon_store.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

const WeaponClass _smallbore = WeaponClass(
  discipline: Discipline.pistol,
  caliberLabel: '.22 LR',
  label: '.22 LR',
);

Weapon _weapon(String id) => Weapon.fromClass(_smallbore, id: id, name: id);

/// A [WeaponStore] whose every `save` fails, to exercise the best-effort
/// persistence path (spec 0019, requirement 3).
class _FailingWeaponStore implements WeaponStore {
  @override
  Future<void> save(List<Weapon> weapons) =>
      Future<void>.error(StateError('save failed'));

  @override
  Future<List<Weapon>> load() async => const <Weapon>[];
}

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

  group('persistence (spec 0019)', () {
    late InMemoryWeaponStore store;

    // A container whose notifier writes to [store] and seeds its initial state
    // from [initial] — the latter simulating a relaunch with a saved list.
    ProviderContainer containerWith({List<Weapon> initial = const <Weapon>[]}) {
      return ProviderContainer(
        overrides: [
          weaponStoreProvider.overrideWithValue(store),
          initialWeaponsProvider.overrideWithValue(initial),
        ],
      );
    }

    setUp(() => store = InMemoryWeaponStore());

    test('add persists the new list to the store', () async {
      final c = containerWith();
      addTearDown(c.dispose);

      c.read(weaponsProvider.notifier).add(_weapon('a'));
      await pumpEventQueue();

      expect(await store.load(), [_weapon('a')]);
    });

    test('add persists the whole accumulated list, in order', () async {
      final c = containerWith();
      addTearDown(c.dispose);

      c.read(weaponsProvider.notifier)
        ..add(_weapon('a'))
        ..add(_weapon('b'));
      await pumpEventQueue();

      // The full list is saved, not just the latest weapon: a regression to
      // `save(<Weapon>[weapon])` would drop the earlier one and fail here.
      expect(await store.load(), [_weapon('a'), _weapon('b')]);
    });

    test(
      'a fresh notifier seeded from the store shows the added weapon',
      () async {
        final first = containerWith();
        first.read(weaponsProvider.notifier).add(_weapon('a'));
        await pumpEventQueue();
        first.dispose();

        // Relaunch: seed a fresh notifier from what the store holds.
        final saved = await store.load();
        final second = containerWith(initial: saved);
        addTearDown(second.dispose);

        expect(second.read(weaponsProvider), [_weapon('a')]);
      },
    );

    test('remove persists the shortened list', () async {
      final c = containerWith(initial: [_weapon('a'), _weapon('b')]);
      addTearDown(c.dispose);

      c.read(weaponsProvider.notifier).remove('a');
      await pumpEventQueue();

      expect(await store.load(), [_weapon('b')]);

      // A relaunch seeded from the store no longer shows the removed weapon.
      final saved = await store.load();
      final relaunched = containerWith(initial: saved);
      addTearDown(relaunched.dispose);
      expect(relaunched.read(weaponsProvider), [_weapon('b')]);
    });

    test(
      'a failing save does not break add (best-effort persistence)',
      () async {
        final c = ProviderContainer(
          overrides: [
            weaponStoreProvider.overrideWithValue(_FailingWeaponStore()),
          ],
        );
        addTearDown(c.dispose);

        // The save fails, but add must not throw and the in-memory list — the
        // source of truth for the run — still reflects the new weapon.
        expect(
          () => c.read(weaponsProvider.notifier).add(_weapon('a')),
          returnsNormally,
        );
        expect(c.read(weaponsProvider), [_weapon('a')]);

        // The rejected save is handled, so draining the queue surfaces no
        // unhandled async error.
        await pumpEventQueue();
      },
    );
  });
}
