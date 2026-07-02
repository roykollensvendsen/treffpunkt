// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the felt session snapshot serialization (spec 0081).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

void main() {
  test('round-trips through JSON, keeping misses and inner (spec 0081)', () {
    const snapshot = FeltSessionSnapshot(
      group: FeltShooterGroup.one,
      currentHold: 2,
      holds: <List<FeltPlacedShot>>[
        <FeltPlacedShot>[
          FeltPlacedShot(dx: 10, dy: 20, figureIndex: 0, inner: true),
          FeltPlacedShot(dx: 5, dy: 5), // a miss
        ],
        <FeltPlacedShot>[],
        <FeltPlacedShot>[FeltPlacedShot(dx: 30.5, dy: 40.25, figureIndex: 3)],
      ],
    );

    final restored = FeltSessionSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );

    expect(restored, snapshot);
    expect(restored.group, FeltShooterGroup.one);
    expect(restored.currentHold, 2);
    expect(restored.totalShots, 3);
    expect(restored.holds[0][1].figureIndex, isNull);
    expect(restored.holds[0][0].inner, isTrue);
  });

  test('a stored gruppe-3 round still loads (spec 0088)', () {
    // Gruppe 3 is no longer offered in the recorder, but a round saved with
    // it must keep resolving — same retained-but-not-offered rule as retired
    // programs (spec 0036).
    const snapshot = FeltSessionSnapshot(
      group: FeltShooterGroup.three,
      currentHold: 0,
      holds: <List<FeltPlacedShot>>[<FeltPlacedShot>[]],
    );
    final restored = FeltSessionSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );
    expect(restored.group, FeltShooterGroup.three);
  });
}
