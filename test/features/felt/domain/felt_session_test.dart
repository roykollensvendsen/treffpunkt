// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the field-shooting session domain (spec 0068): totals sum hits and
// inner hits, and a hold is clamped so hits stay within shots-per-hold and
// inner hits never exceed the hold's hits.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_session.dart';

void main() {
  test('a fresh session is ten empty holds with a class max', () {
    final session = FeltSession.start(FeltClass.fin);
    expect(session.holdCount, 10);
    expect(session.shotsPerHold, 6);
    expect(session.maxHits, 60);
    expect(session.totalHits, 0);
    expect(session.totalInnerHits, 0);
  });

  test('totals sum hits and inner hits across holds', () {
    var session = FeltSession.start(FeltClass.grov);
    session = session.withHold(0, hits: 6, innerHits: 2);
    session = session.withHold(1, hits: 5, innerHits: 1);
    expect(session.totalHits, 11);
    expect(session.totalInnerHits, 3);
  });

  test('hits are clamped to shots-per-hold and to zero', () {
    var session = FeltSession.start(FeltClass.fin);
    session = session.withHold(0, hits: 9, innerHits: 0); // over the 6 max
    expect(session.holds[0].hits, 6);
    session = session.withHold(0, hits: -3, innerHits: 0);
    expect(session.holds[0].hits, 0);
  });

  test('inner hits can never exceed the hold hits', () {
    var session = FeltSession.start(FeltClass.fin);
    session = session.withHold(
      0,
      hits: 3,
      innerHits: 5,
    ); // more inner than hits
    expect(session.holds[0].innerHits, 3);
    // Lowering hits also lowers inner that would now exceed it.
    session = session.withHold(0, hits: 1, innerHits: 3);
    expect(session.holds[0].hits, 1);
    expect(session.holds[0].innerHits, 1);
  });
}
