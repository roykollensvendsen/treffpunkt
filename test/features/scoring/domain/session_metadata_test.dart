// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the SessionMetadata value type (spec 0008).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';

void main() {
  final when = DateTime.utc(2026, 6, 21, 14, 30);

  test('holds the supplied DateTime verbatim and an optional place', () {
    final metadata = SessionMetadata(capturedAt: when);
    expect(metadata.capturedAt, when);
    expect(metadata.place, isNull);
  });

  test('equal metadata compare equal and share a hash', () {
    const place = Place(label: 'Range');
    final a = SessionMetadata(capturedAt: when, place: place);
    final b = SessionMetadata(capturedAt: when, place: place);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('metadata differing in any field are not equal', () {
    final base = SessionMetadata(
      capturedAt: when,
      place: const Place(label: 'Range'),
    );
    expect(
      base ==
          SessionMetadata(
            capturedAt: when.add(const Duration(days: 1)),
            place: const Place(label: 'Range'),
          ),
      isFalse,
    );
    expect(base == SessionMetadata(capturedAt: when), isFalse);
  });

  test('copyWith replaces only the named fields', () {
    final base = SessionMetadata(
      capturedAt: when,
      place: const Place(label: 'Range'),
    );
    final later = when.add(const Duration(hours: 1));

    expect(
      base.copyWith(capturedAt: later),
      SessionMetadata(
        capturedAt: later,
        place: const Place(label: 'Range'),
      ),
    );
    expect(
      base.copyWith(place: const Place(label: 'Other')),
      SessionMetadata(
        capturedAt: when,
        place: const Place(label: 'Other'),
      ),
    );
    expect(base.copyWith(), base);
  });
}
