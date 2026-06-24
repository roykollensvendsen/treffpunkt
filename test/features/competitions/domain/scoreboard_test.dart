// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the scoreboard ranking (spec 0013): one row per shooter (their
// best), ordered best first, ties broken by inner tens then the earlier shot.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/scoreboard.dart';

CompetitionResult _r(
  String id, {
  required int total,
  String? user,
  int innerTens = 0,
  DateTime? at,
}) => CompetitionResult(
  id: id,
  competitionId: 'c1',
  userId: user,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 600,
  innerTens: innerTens,
  capturedAt: at,
  payload: const <String, dynamic>{},
);

void main() {
  test('empty in, empty out', () {
    expect(rankBestPerShooter(const <CompetitionResult>[]), isEmpty);
  });

  test('keeps each shooter once, with their best total', () {
    final ranked = rankBestPerShooter(<CompetitionResult>[
      _r('a1', user: 'a', total: 560),
      _r('a2', user: 'a', total: 580),
      _r('b1', user: 'b', total: 570),
    ]);
    expect(ranked.map((r) => r.userId), <String>['a', 'b']); // best first
    expect(ranked.map((r) => r.id), <String>['a2', 'b1']); // a's best kept
    expect(ranked.first.total, 580);
  });

  test('a tie on total ranks more inner tens first', () {
    final ranked = rankBestPerShooter(<CompetitionResult>[
      _r('a', user: 'a', total: 580, innerTens: 3),
      _r('b', user: 'b', total: 580, innerTens: 8),
    ]);
    expect(ranked.map((r) => r.userId), <String>['b', 'a']);
  });

  test('a full tie keeps the earlier shot ahead', () {
    final ranked = rankBestPerShooter(<CompetitionResult>[
      _r('late', user: 'a', total: 580, at: DateTime.utc(2026, 6, 23, 12)),
      _r('early', user: 'b', total: 580, at: DateTime.utc(2026, 6, 23, 10)),
    ]);
    expect(ranked.map((r) => r.id), <String>['early', 'late']);
  });

  test('results with no user are each their own row', () {
    final ranked = rankBestPerShooter(<CompetitionResult>[
      _r('x', total: 500),
      _r('y', total: 510),
    ]);
    expect(ranked.map((r) => r.id), <String>['y', 'x']);
  });
}
