// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the pure-Dart JSON (de)serialization of personal weapons:
// a lossless round-trip for weapons with and without make/model/notes, the
// discipline carried by name, and the empty list.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapons_snapshot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

const Weapon _full = Weapon(
  id: 'w1',
  name: 'My Walther',
  discipline: Discipline.pistol,
  caliberLabel: '.22 LR',
  classLabel: '.22 LR',
  make: 'Walther',
  model: 'GSP',
  notes: 'club gun',
);

const Weapon _minimal = Weapon(
  id: 'w2',
  name: 'Air rifle',
  discipline: Discipline.rifle,
  caliberLabel: '4.5 mm',
  classLabel: 'Air 4.5 mm',
);

void main() {
  group('WeaponsSnapshot', () {
    test('round-trips a weapon with every optional field set', () {
      final restored = WeaponsSnapshot.fromJson(
        WeaponsSnapshot.toJson(<Weapon>[_full]),
      );
      expect(restored, <Weapon>[_full]);
      expect(restored.single.make, 'Walther');
      expect(restored.single.model, 'GSP');
      expect(restored.single.notes, 'club gun');
      expect(restored.single.discipline, Discipline.pistol);
    });

    test('round-trips a weapon with no make/model/notes (all null)', () {
      final restored = WeaponsSnapshot.fromJson(
        WeaponsSnapshot.toJson(<Weapon>[_minimal]),
      );
      expect(restored, <Weapon>[_minimal]);
      expect(restored.single.make, isNull);
      expect(restored.single.model, isNull);
      expect(restored.single.notes, isNull);
      expect(restored.single.discipline, Discipline.rifle);
    });

    test('round-trips a list mixing full and partial weapons, in order', () {
      const weapons = <Weapon>[_full, _minimal];
      expect(
        WeaponsSnapshot.fromJson(WeaponsSnapshot.toJson(weapons)),
        weapons,
      );
    });

    test('round-trips an empty list', () {
      expect(
        WeaponsSnapshot.fromJson(WeaponsSnapshot.toJson(const <Weapon>[])),
        isEmpty,
      );
    });

    test('stores the discipline by its enum name', () {
      expect(
        WeaponsSnapshot.toJson(<Weapon>[_full]).single['discipline'],
        'pistol',
      );
      expect(
        WeaponsSnapshot.toJson(<Weapon>[_minimal]).single['discipline'],
        'rifle',
      );
    });
  });
}
