// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the in-memory felt session repository (spec 0083).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

FeltSessionRecord _record(String id, {required DateTime at}) =>
    FeltSessionRecord(
      id: id,
      capturedAt: at,
      session: const FeltSessionSnapshot(
        group: FeltShooterGroup.one,
        currentHold: 0,
        holds: <List<FeltPlacedShot>>[
          <FeltPlacedShot>[FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0)],
        ],
      ),
    );

void main() {
  test('upload is idempotent by id (spec 0083)', () async {
    final repository = InMemoryFeltSessionRepository();
    await repository.upload(_record('a', at: DateTime.utc(2026, 7, 5)));
    await repository.upload(_record('a', at: DateTime.utc(2026, 7, 6)));
    await repository.upload(_record('b', at: DateTime.utc(2026, 7, 4)));

    final rounds = await repository.list();
    expect(rounds.map((r) => r.id), <String>['a', 'b']); // newest first
    expect(rounds.length, 2);
  });
}
