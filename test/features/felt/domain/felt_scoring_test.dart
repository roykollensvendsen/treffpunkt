// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for NorgesFelt hit scoring (spec 0080).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

void main() {
  test('group sets the shots per hold: 6 / 5 / 5 (spec 0080)', () {
    expect(FeltShooterGroup.one.shotsPerHold, 6);
    expect(FeltShooterGroup.two.shotsPerHold, 5);
    expect(FeltShooterGroup.three.shotsPerHold, 5);
  });

  test('only gruppe 1 and 2 are offered; 3 stays resolvable (spec 0088)', () {
    // Gruppe 3 is not shot on NorgesFelt (heavier weapons) so the recorder
    // does not offer it — but a stored round with it must keep loading.
    expect(FeltShooterGroup.offered, <FeltShooterGroup>[
      FeltShooterGroup.one,
      FeltShooterGroup.two,
    ]);
    expect(FeltShooterGroup.values, contains(FeltShooterGroup.three));
    expect(FeltShooterGroup.values.byName('three'), FeltShooterGroup.three);
  });

  test(
    'hold scores treff + distinct figures; inner adds nothing (spec 0085)',
    () {
      // Six hits across five figures, all six in an inner zone → 6 + 5 = 11.
      // The inner hits are counted (the tiebreaker) but give no points.
      const tally = FeltHoldTally(<FeltShot>[
        FeltShot(figureIndex: 0, inner: true),
        FeltShot(figureIndex: 0, inner: true),
        FeltShot(figureIndex: 1, inner: true),
        FeltShot(figureIndex: 2, inner: true),
        FeltShot(figureIndex: 3, inner: true),
        FeltShot(figureIndex: 4, inner: true),
      ]);
      expect(tally.treff, 6);
      expect(tally.figures, 5);
      expect(tally.inner, 6);
      expect(tally.points, 11);
    },
  );

  test(
    'a miss scores nothing; a plain hit scores treff + figure (spec 0080)',
    () {
      const tally = FeltHoldTally(<FeltShot>[
        FeltShot(),
        FeltShot(figureIndex: 2),
      ]);
      expect(tally.treff, 1);
      expect(tally.figures, 1);
      expect(tally.inner, 0);
      expect(tally.points, 2);
    },
  );

  test('session totals the holds and sums the tiebreak inner (spec 0085)', () {
    const session = FeltSessionTally(
      group: FeltShooterGroup.one,
      holds: <FeltHoldTally>[
        FeltHoldTally(<FeltShot>[FeltShot(figureIndex: 0, inner: true)]),
        FeltHoldTally(<FeltShot>[FeltShot(figureIndex: 1)]),
        FeltHoldTally(<FeltShot>[FeltShot(figureIndex: 0, inner: true)]),
      ],
    );
    expect(session.holds.first.points, 2);
    expect(session.holds.last.points, 2);
    expect(session.points, 6);
    // The session-level inner count — the tiebreaker when points are equal.
    expect(session.inner, 2);
  });
}
