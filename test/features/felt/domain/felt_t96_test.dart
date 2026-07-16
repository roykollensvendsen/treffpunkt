// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the T96 («Kråkefelt») course (spec 0160): the 16-series
// program of reglement-felt-t96-2026 § 8.26, the inner-scoring tally, the
// offered groups and the Magnum position exception.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

void main() {
  group('T96 course structure (spec 0160, § 8.26.3)', () {
    test('16 series over 11/15/25 m with the rulebook times', () {
      expect(t96Course.holds, hasLength(16));
      expect(
        t96Course.holds.map((h) => h.number).toList(),
        List<int>.generate(16, (i) => i + 1),
      );
      const blockTimes = <String>[
        '150 sek',
        '150 sek',
        '20 sek',
        '20 sek',
        '10 sek',
        '10 sek',
      ];
      for (var i = 0; i < 16; i++) {
        final hold = t96Course.holds[i];
        final distance = i < 6
            ? '11 m'
            : i < 12
            ? '15 m'
            : '25 m';
        expect(hold.distance, distance, reason: 'serie ${i + 1}');
        final time = i < 12 ? blockTimes[i % 6] : blockTimes[i - 12];
        expect(hold.time, time, reason: 'serie ${i + 1}');
      }
    });

    test('positions alternate fri / 1 hånd; 25 m is all fri', () {
      for (var i = 0; i < 16; i++) {
        final expected = i >= 12 || i.isEven ? 'Stående fri' : 'Stående 1 hånd';
        expect(
          t96Course.holds[i].position,
          expected,
          reason: 'serie ${i + 1}',
        );
      }
    });

    test(
      'every series is five ⌀11 cm circles with 4,5 cm inner (§ 8.26.4)',
      () {
        for (final hold in t96Course.holds) {
          expect(hold.figures, hasLength(5), reason: 'serie ${hold.number}');
          for (final figure in hold.figures) {
            expect(figure.type, FeltFigureType.circle);
            // The T96 figure is a full circle — not the flat-cut C-figure.
            expect(figure.widthCm, 11);
            expect(figure.heightCm, 11);
            expect(figure.innerCm, 4.5);
          }
        }
      },
    );
  });

  test('T96 maxima are 272/240/240; the others unchanged (spec 0160)', () {
    // Per series: shots + min(shots, 5 figures) + shots inner points.
    expect(t96Course.maxPoints(FeltShooterGroup.one), 272);
    expect(t96Course.maxPoints(FeltShooterGroup.two), 240);
    expect(t96Course.maxPoints(FeltShooterGroup.three), 240);
    expect(norgesfelt2026Course.maxPoints(FeltShooterGroup.one), 80);
    expect(norgesfelt2026Course.maxPoints(FeltShooterGroup.two), 70);
    expect(askerPlusCourse.maxPoints(FeltShooterGroup.one), 103);
    expect(askerPlusCourse.maxPoints(FeltShooterGroup.two), 90);
  });

  test('inner zones score a point on T96 (§ 8.26.5 example = 17)', () {
    // «Har du 6 treff fordelt på 5 figurer og 6 innersoner, får du totalt
    // 17 poeng.»
    final shots = <FeltShot>[
      for (var figure = 0; figure < 5; figure++)
        FeltShot(figureIndex: figure, inner: true),
      const FeltShot(figureIndex: 0, inner: true),
    ];
    expect(FeltHoldTally(shots, innerScores: true).points, 17);
    // The NorgesFelt rule is untouched: inner stays a scoreless tiebreak.
    expect(FeltHoldTally(shots).points, 11);
  });

  test('a stored T96 round tallies with inner points (spec 0160)', () {
    FeltSessionRecord record(String? courseId) => FeltSessionRecord(
      id: 'r1',
      capturedAt: DateTime.utc(2026, 7, 16),
      session: FeltSessionSnapshot(
        group: FeltShooterGroup.two,
        courseId: courseId,
        currentHold: 0,
        holds: const <List<FeltPlacedShot>>[
          <FeltPlacedShot>[
            FeltPlacedShot(dx: 1, dy: 1, figureIndex: 0, inner: true),
          ],
        ],
      ),
    );
    // T96: 1 treff + 1 figur + 1 inner; without a course id the round is a
    // NorgesFelt round and the inner adds nothing.
    expect(record(t96Course.id).points, 3);
    expect(record(null).points, 2);
  });

  test('T96 offers Gruppe 3; the NorgesFelt courses do not (spec 0160)', () {
    expect(t96Course.offeredGroups, <FeltShooterGroup>[
      FeltShooterGroup.one,
      FeltShooterGroup.two,
      FeltShooterGroup.three,
    ]);
    expect(norgesfelt2026Course.offeredGroups, FeltShooterGroup.offered);
    expect(askerPlusCourse.offeredGroups, FeltShooterGroup.offered);
  });

  test('Magnum shoots every series with two hands (§ 8.26.3 unntak)', () {
    for (final hold in t96Course.holds) {
      expect(
        t96Course.positionFor(hold, FeltShooterGroup.three),
        'Stående 2 hender',
        reason: 'serie ${hold.number}',
      );
      expect(
        t96Course.positionFor(hold, FeltShooterGroup.one),
        hold.position,
      );
      expect(
        t96Course.positionFor(hold, FeltShooterGroup.two),
        hold.position,
      );
    }
    // NorgesFelt has no override for any group.
    final norgesfeltHold = norgesfelt2026Course.holds.first;
    expect(
      norgesfelt2026Course.positionFor(norgesfeltHold, FeltShooterGroup.three),
      norgesfeltHold.position,
    );
  });

  test('T96 words, lookup and program encodings (spec 0160)', () {
    expect(t96Course.name, 'T96');
    expect(t96Course.stationWord, 'Serie');
    expect(t96Course.stationWordPlural, 'serier');
    expect(norgesfelt2026Course.stationWord, 'Hold');
    expect(norgesfelt2026Course.stationWordPlural, 'hold');
    expect(t96Course.innerScores, isTrue);
    expect(t96Course.note, contains('to hender'));
    expect(feltCourses.last, same(t96Course));
    expect(feltCourseById('t96'), same(t96Course));
    expect(t96Course.programName(FeltShooterGroup.three), 'T96 (Gruppe 3)');
    expect(t96Course.recordKey(FeltShooterGroup.one), 'T96 · Gruppe 1');
  });
}
