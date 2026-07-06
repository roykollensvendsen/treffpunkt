// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the shared SharedPreferences JSON-store skeletons that the
// concrete feature stores (session, pending uploads, felt history, weapons,
// personal records, …) are built on.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';

/// A minimal value type standing in for the domain snapshots/records the
/// concrete stores persist. Records give value equality for free.
typedef _Point = ({int x, int y});

Object? _pointToJson(_Point point) => <String, dynamic>{
  'x': point.x,
  'y': point.y,
};

_Point _pointFromJson(Object? json) {
  final map = json! as Map<String, dynamic>;
  return (x: map['x'] as int, y: map['y'] as int);
}

PrefsJsonStore<_Point> _valueStore(SharedPreferences prefs) =>
    PrefsJsonStore<_Point>(
      prefs,
      key: 'point',
      toJson: _pointToJson,
      fromJson: _pointFromJson,
    );

PrefsJsonListStore<_Point> _listStore(SharedPreferences prefs) =>
    PrefsJsonListStore<_Point>(
      prefs,
      key: 'points',
      toJson: _pointToJson,
      fromJson: _pointFromJson,
    );

Future<SharedPreferences> _prefs([Map<String, Object>? initial]) {
  SharedPreferences.setMockInitialValues(initial ?? <String, Object>{});
  return SharedPreferences.getInstance();
}

void main() {
  group('PrefsJsonStore', () {
    test('load returns null before any save', () async {
      final store = _valueStore(await _prefs());
      expect(await store.load(), isNull);
    });

    test('save then load round-trips the value through the codecs', () async {
      final store = _valueStore(await _prefs());
      await store.save((x: 3, y: 7));
      expect(await store.load(), (x: 3, y: 7));
    });

    test('save replaces the previously saved value', () async {
      final store = _valueStore(await _prefs());
      await store.save((x: 1, y: 1));
      await store.save((x: 2, y: 2));
      expect(await store.load(), (x: 2, y: 2));
    });

    test('clear removes the saved value', () async {
      final store = _valueStore(await _prefs());
      await store.save((x: 1, y: 1));
      await store.clear();
      expect(await store.load(), isNull);
    });

    test('malformed JSON loads as null instead of throwing', () async {
      final store = _valueStore(await _prefs({'point': 'not json {'}));
      expect(await store.load(), isNull);
    });

    test('a wrong JSON shape loads as null instead of throwing', () async {
      // Valid JSON, but the codec expects an object with int x/y.
      final store = _valueStore(await _prefs({'point': '["a","list"]'}));
      expect(await store.load(), isNull);
    });

    test('stores under different keys do not collide', () async {
      final prefs = await _prefs();
      final a = PrefsJsonStore<_Point>(
        prefs,
        key: 'a',
        toJson: _pointToJson,
        fromJson: _pointFromJson,
      );
      final b = PrefsJsonStore<_Point>(
        prefs,
        key: 'b',
        toJson: _pointToJson,
        fromJson: _pointFromJson,
      );
      await a.save((x: 1, y: 1));
      expect(await b.load(), isNull);
      await b.save((x: 2, y: 2));
      await a.clear();
      expect(await b.load(), (x: 2, y: 2));
    });
  });

  group('PrefsJsonListStore', () {
    test('load is empty before any save', () async {
      final store = _listStore(await _prefs());
      expect(await store.load(), isEmpty);
    });

    test('save then load round-trips the items in order', () async {
      final store = _listStore(await _prefs());
      await store.save(const <_Point>[(x: 1, y: 2), (x: 3, y: 4)]);
      expect(await store.load(), const <_Point>[(x: 1, y: 2), (x: 3, y: 4)]);
    });

    test('save replaces the whole list, and save([]) empties it', () async {
      final store = _listStore(await _prefs());
      await store.save(const <_Point>[(x: 1, y: 1)]);
      await store.save(const <_Point>[(x: 9, y: 9)]);
      expect(await store.load(), const <_Point>[(x: 9, y: 9)]);
      await store.save(const <_Point>[]);
      expect(await store.load(), isEmpty);
    });

    test('malformed JSON loads as empty instead of throwing', () async {
      final store = _listStore(await _prefs({'points': '[{"x":'}));
      expect(await store.load(), isEmpty);
    });

    test('a non-array JSON value loads as empty instead of throwing', () async {
      final store = _listStore(await _prefs({'points': '{"x":1,"y":2}'}));
      expect(await store.load(), isEmpty);
    });

    test('one undecodable item empties the whole list', () async {
      // Matches the felt-history policy: a partially broken store reads as
      // empty rather than silently dropping items.
      final store = _listStore(
        await _prefs({'points': '[{"x":1,"y":2},{"x":"bad"}]'}),
      );
      expect(await store.load(), isEmpty);
    });
  });
}
