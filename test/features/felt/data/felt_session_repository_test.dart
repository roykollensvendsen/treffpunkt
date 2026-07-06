// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the in-memory felt session repository (spec 0083).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';

import '../../../support/records.dart';

void main() {
  test('upload is idempotent by id (spec 0083)', () async {
    final repository = InMemoryFeltSessionRepository();
    await repository.upload(
      feltSessionRecord(id: 'a', capturedAt: DateTime.utc(2026, 7, 5)),
    );
    await repository.upload(
      feltSessionRecord(id: 'a', capturedAt: DateTime.utc(2026, 7, 6)),
    );
    await repository.upload(
      feltSessionRecord(id: 'b', capturedAt: DateTime.utc(2026, 7, 4)),
    );

    final rounds = await repository.list();
    expect(rounds.map((r) => r.id), <String>['a', 'b']); // newest first
    expect(rounds.length, 2);
  });
}
