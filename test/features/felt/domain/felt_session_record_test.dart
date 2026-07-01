// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the finished felt-round record (spec 0082).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

void main() {
  final record = FeltSessionRecord(
    id: 'abc',
    capturedAt: DateTime.utc(2026, 7, 1, 12, 30),
    session: const FeltSessionSnapshot(
      group: FeltShooterGroup.one,
      currentHold: 1,
      holds: <List<FeltPlacedShot>>[
        <FeltPlacedShot>[
          FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0, inner: true),
          FeltPlacedShot(dx: 3, dy: 4, figureIndex: 1),
        ],
        <FeltPlacedShot>[],
      ],
    ),
  );

  test('round-trips through JSON (spec 0082)', () {
    final restored = FeltSessionRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
    expect(restored, record);
    expect(restored.id, 'abc');
    expect(restored.capturedAt, DateTime.utc(2026, 7, 1, 12, 30));
  });

  test('scores its tally from the snapshot (spec 0082)', () {
    // Hold 1: two hits over two figures, one inner → 2 + 2 + 1 = 5.
    expect(record.tally.holds.first.treff, 2);
    expect(record.tally.holds.first.figures, 2);
    expect(record.tally.holds.first.inner, 1);
    expect(record.points, 5);
  });
}
