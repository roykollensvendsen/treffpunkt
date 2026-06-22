// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the Place value type (spec 0008).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';

void main() {
  test('a label-only place has null coordinates', () {
    const place = Place(label: 'Løvenskiold skytebane');
    expect(place.label, 'Løvenskiold skytebane');
    expect(place.latitude, isNull);
    expect(place.longitude, isNull);
  });

  test('equal places compare equal and share a hash', () {
    const a = Place(label: 'Range', latitude: 59.9, longitude: 10.7);
    const b = Place(label: 'Range', latitude: 59.9, longitude: 10.7);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('places differing in any field are not equal', () {
    const base = Place(label: 'Range', latitude: 59.9, longitude: 10.7);
    expect(
      base == const Place(label: 'Other', latitude: 59.9, longitude: 10.7),
      isFalse,
    );
    expect(
      base == const Place(label: 'Range', latitude: 1, longitude: 10.7),
      isFalse,
    );
    expect(
      base == const Place(label: 'Range', latitude: 59.9, longitude: 1),
      isFalse,
    );
  });

  test('copyWith replaces only the named fields', () {
    const base = Place(label: 'Range', latitude: 59.9, longitude: 10.7);

    expect(
      base.copyWith(label: 'New'),
      const Place(label: 'New', latitude: 59.9, longitude: 10.7),
    );
    expect(
      base.copyWith(latitude: 1),
      const Place(label: 'Range', latitude: 1, longitude: 10.7),
    );
    expect(
      base.copyWith(longitude: 2),
      const Place(label: 'Range', latitude: 59.9, longitude: 2),
    );
    expect(base.copyWith(), base);
  });
}
