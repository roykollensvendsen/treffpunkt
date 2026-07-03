// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for decimal entry on the uniform 1–10 faces (spec 0107).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

const ScoringService scoring = ScoringService();

void main() {
  const airPistol = TargetGeometry.airPistol10m();

  group('TargetGeometry.supportsDecimalScore (spec 0107)', () {
    test('true for the uniform 1–10 faces', () {
      expect(const TargetGeometry.airPistol10m().supportsDecimalScore, isTrue);
      expect(const TargetGeometry.airRifle10m().supportsDecimalScore, isTrue);
      expect(
        const TargetGeometry.pistol25mPrecision().supportsDecimalScore,
        isTrue,
      );
    });

    test('true for the 5–10 faces too — their bands are uniform (0114)', () {
      expect(
        const TargetGeometry.pistol25mRapid().supportsDecimalScore,
        isTrue,
      );
      expect(const TargetGeometry.airDuel10m().supportsDecimalScore, isTrue);
    });
  });

  group('Shot.tenth and Series.setShotTenth (spec 0107)', () {
    test('a shot carries no tenth unless one is picked', () {
      expect(const Shot(dxMm: 0, dyMm: 0).tenth, isNull);
    });

    test('setShotTenth sets, replaces and clears the tenth', () {
      var series = Series(
        geometry: airPistol,
        capacity: 5,
      ).placeShot(const Shot(dxMm: 10, dyMm: 0));

      series = series.setShotTenth(0, 4);
      expect(series.shots.single.tenth, 4);
      // The position is untouched.
      expect(series.shots.single.dxMm, 10);

      series = series.setShotTenth(0, 7);
      expect(series.shots.single.tenth, 7);

      series = series.setShotTenth(0, null);
      expect(series.shots.single.tenth, isNull);
    });

    test('setShotTenth on an unplaced index throws', () {
      final series = Series(geometry: airPistol, capacity: 5);
      expect(() => series.setShotTenth(0, 3), throwsRangeError);
    });

    test('removeLastShot drops the tenth with the shot', () {
      var series = Series(
        geometry: airPistol,
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0)).setShotTenth(0, 6);
      series = series.removeLastShot();
      expect(series.shots, isEmpty);
    });
  });

  group('ScoringService.decimalTenths (spec 0107)', () {
    test('derives the tenth from the position when none is picked', () {
      // Dead centre on the air-pistol face → 10,9 (spec 0001's cap).
      expect(
        scoring.decimalTenths(airPistol, const Shot(dxMm: 0, dyMm: 0)),
        109,
      );
      // The derived decimal always floors to the plotted ring.
      const shot = Shot(dxMm: 10, dyMm: 0);
      final tenths = scoring.decimalTenths(airPistol, shot);
      expect(tenths ~/ 10, scoring.integerScore(airPistol, shot));
    });

    test('a picked tenth overrides the derived one within the ring', () {
      const shot = Shot(dxMm: 10, dyMm: 0, tenth: 4);
      final ring = scoring.integerScore(airPistol, shot);
      expect(scoring.decimalTenths(airPistol, shot), ring * 10 + 4);
    });

    test('a miss is 0,0 — a picked tenth cannot resurrect it', () {
      const miss = Shot(dxMm: 500, dyMm: 0, tenth: 9);
      expect(scoring.decimalTenths(airPistol, miss), 0);
    });

    test('the 5–10 duel faces derive decimals too (spec 0114)', () {
      const rapid = TargetGeometry.pistol25mRapid();
      // Dead centre → the cap, 10,9.
      expect(scoring.decimalTenths(rapid, const Shot(dxMm: 0, dyMm: 0)), 109);
      // The derived decimal floors to the plotted ring across the face.
      for (final dx in const [30.0, 90.0, 150.0, 210.0, 249.0]) {
        final shot = Shot(dxMm: dx, dyMm: 0);
        expect(
          scoring.decimalTenths(rapid, shot) ~/ 10,
          scoring.integerScore(rapid, shot),
          reason: 'dx $dx',
        );
      }
      // The outermost edge of ring 5 reads 5,0 — never below the ring.
      const edge = Shot(dxMm: 252, dyMm: 0);
      expect(scoring.decimalTenths(rapid, edge), 50);
    });
  });

  group('shotAtDecimalTenth (spec 0110)', () {
    test('moves the shot to the picked decimal, ring and angle kept', () {
      const shot = Shot(dxMm: 10, dyMm: 0); // ring 9, due east
      final ring = scoring.integerScore(airPistol, shot);
      final moved = scoring.shotAtDecimalTenth(airPistol, shot, 4);

      // The position now *is* the picked value.
      expect(scoring.decimalTenths(airPistol, moved), ring * 10 + 4);
      expect(scoring.integerScore(airPistol, moved), ring);
      // Radial move only: still due east.
      expect(moved.dyMm, 0);
      expect(moved.dxMm, greaterThan(0));
      expect(moved.tenth, 4);
    });

    test('every tenth of the ring round-trips through the position', () {
      const shot = Shot(dxMm: 10, dyMm: 0); // ring 9
      for (var tenth = 0; tenth <= 9; tenth++) {
        final moved = scoring.shotAtDecimalTenth(airPistol, shot, tenth);
        expect(
          scoring.decimalTenths(airPistol, moved),
          90 + tenth,
          reason: 'tenth $tenth',
        );
      }
    });

    test('a higher decimal sits closer to the centre', () {
      const shot = Shot(dxMm: 10, dyMm: 0);
      final at94 = scoring.shotAtDecimalTenth(airPistol, shot, 4);
      final at97 = scoring.shotAtDecimalTenth(airPistol, shot, 7);
      expect(at97.distanceMm, lessThan(at94.distanceMm));
    });

    test('a dead-centre shot still gets a position for its tenth', () {
      const centre = Shot(dxMm: 0, dyMm: 0); // ring 10, no direction
      final moved = scoring.shotAtDecimalTenth(airPistol, centre, 4);
      expect(moved.distanceMm, greaterThan(0));
      expect(scoring.decimalTenths(airPistol, moved), 104);
    });

    test('picking 10,9 lands inside the inner ten (the Megalink truth)', () {
      const shot = Shot(dxMm: 7, dyMm: 0); // ring 10, outside the X-ring
      expect(scoring.isInnerTen(airPistol, shot), isFalse);
      final moved = scoring.shotAtDecimalTenth(airPistol, shot, 9);
      expect(scoring.isInnerTen(airPistol, moved), isTrue);
    });

    test('a miss is untouched — nothing to position', () {
      const miss = Shot(dxMm: 500, dyMm: 0);
      final moved = scoring.shotAtDecimalTenth(airPistol, miss, 9);
      expect(moved.dxMm, 500);
      expect(scoring.decimalTenths(airPistol, moved), 0);
    });
  });

  group('decimal totals on the score rollup (spec 0107)', () {
    test('a series on a decimal face sums the tenths exactly', () {
      final series = Series(geometry: airPistol, capacity: 5)
          .placeShot(const Shot(dxMm: 0, dyMm: 0)) // 10,9
          .placeShot(const Shot(dxMm: 10, dyMm: 0, tenth: 4)); // 9,4
      final score = scoring.scoreSeries(series);
      expect(score.shots[0].decimal, 10.9);
      expect(score.shots[1].decimal, 9.4);
      expect(score.decimalTotal, closeTo(20.3, 1e-9));
    });

    test('a series on a 5–10 face sums decimals too (spec 0114)', () {
      final series = Series(
        geometry: const TargetGeometry.pistol25mRapid(),
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0));
      final score = scoring.scoreSeries(series);
      expect(score.decimalTotal, 10.9);
      expect(score.shots.single.decimal, 10.9);
    });

    test('the session rolls the decimal totals up', () {
      var session = Session.start(
        ProgramCatalogue.airRifle10m,
        decimalEntry: true,
      );
      final series = Series(
        geometry: airPistol,
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0));
      session = session.sealSeries(series);
      final score = scoring.scoreSession(session);
      expect(score.stages.first.decimalTotal, 10.9);
      expect(score.decimalTotal, 10.9);
    });
  });

  group('the precision-face programs offer decimals (spec 0111)', () {
    test('every all-decimal or mixed precision program is flagged', () {
      expect(ProgramCatalogue.standardPistol25m.supportsDecimalEntry, isTrue);
      expect(ProgramCatalogue.freePistol50m.supportsDecimalEntry, isTrue);
      // Mixed programs (presisjon + duell) offer it too: the precision
      // series get decimals, the duel series stay integer.
      expect(ProgramCatalogue.finpistol25m.supportsDecimalEntry, isTrue);
      expect(ProgramCatalogue.grovpistol25m.supportsDecimalEntry, isTrue);
    });

    test('the 5–10-face programs offer it too (spec 0114)', () {
      expect(ProgramCatalogue.sprintluft.supportsDecimalEntry, isTrue);
      expect(ProgramCatalogue.storluftDuel.supportsDecimalEntry, isTrue);
      expect(
        ProgramCatalogue.hurtigpistolFin25m.supportsDecimalEntry,
        isTrue,
      );
      expect(ProgramCatalogue.silhuettpistol25m.supportsDecimalEntry, isTrue);
      expect(ProgramCatalogue.naisFin25m.supportsDecimalEntry, isTrue);
    });
  });

  group('runningDecimalTotal (spec 0111)', () {
    test('sums sealed and current series on decimal faces', () {
      var session = Session.start(
        ProgramCatalogue.airPistol10m,
        decimalEntry: true,
      );
      final sealed = Series(
        geometry: airPistol,
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0)); // 10,9
      session = session.sealSeries(sealed);
      final current = Series(
        geometry: airPistol,
        capacity: 5,
      ).placeShot(const Shot(dxMm: 10, dyMm: 0, tenth: 4)); // 9,4
      expect(scoring.runningDecimalTotal(session, current), 20.3);
    });

    test('a mixed program sums across both faces (spec 0114)', () {
      var session = Session.start(
        ProgramCatalogue.finpistol25m,
        decimalEntry: true,
      );
      final precision = Series(
        geometry: const TargetGeometry.pistol25mPrecision(),
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0));
      session = session.sealSeries(precision);
      final duel = Series(
        geometry: const TargetGeometry.pistol25mRapid(),
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0));
      // Both faces carry decimals now: 10,9 + 10,9.
      expect(scoring.runningDecimalTotal(session, duel), 21.8);
    });

    test('an empty current series still reports the sealed total', () {
      var session = Session.start(
        ProgramCatalogue.airPistol10m,
        decimalEntry: true,
      );
      session = session.sealSeries(
        Series(
          geometry: airPistol,
          capacity: 5,
        ).placeShot(const Shot(dxMm: 0, dyMm: 0)),
      );
      final empty = Series(geometry: airPistol, capacity: 5);
      expect(scoring.runningDecimalTotal(session, empty), 10.9);
    });
  });

  group('Session.decimalEntry (spec 0107)', () {
    test('defaults off and survives sealSeries', () {
      const program = ProgramCatalogue.airRifle10m;
      expect(Session.start(program).decimalEntry, isFalse);
      var session = Session.start(program, decimalEntry: true);
      expect(session.decimalEntry, isTrue);
      session = session.sealSeries(session.newSeries()!);
      expect(session.decimalEntry, isTrue);
    });
  });

  group('snapshot round-trip (spec 0107)', () {
    test('tenths and the flag survive save and load', () {
      final program = ProgramCatalogue.all.first;
      final current = Series(
        geometry: program.stages.first.geometry,
        capacity: program.stages.first.shotsPerSeries,
      ).placeShot(const Shot(dxMm: 10, dyMm: 0)).setShotTenth(0, 4);
      final snapshot = SessionSnapshot(
        session: Session.start(program, decimalEntry: true),
        current: current,
        id: 'x1',
      );

      final restored = SessionSnapshot.fromJson(snapshot.toJson());
      expect(restored.session.decimalEntry, isTrue);
      expect(restored.current!.shots.single.tenth, 4);
      expect(restored, snapshot);
    });

    test('a differing tenth breaks snapshot equality', () {
      final program = ProgramCatalogue.all.first;
      Series series(int? tenth) => Series(
        geometry: program.stages.first.geometry,
        capacity: program.stages.first.shotsPerSeries,
      ).placeShot(Shot(dxMm: 10, dyMm: 0, tenth: tenth));
      final a = SessionSnapshot(
        session: Session.start(program),
        current: series(4),
        id: 'x1',
      );
      final b = SessionSnapshot(
        session: Session.start(program),
        current: series(5),
        id: 'x1',
      );
      expect(a == b, isFalse);
    });

    test('an old snapshot without the keys loads unchanged', () {
      final program = ProgramCatalogue.all.first;
      final json =
          SessionSnapshot(
              session: Session.start(program),
              current: Series(
                geometry: program.stages.first.geometry,
                capacity: program.stages.first.shotsPerSeries,
              ).placeShot(const Shot(dxMm: 5, dyMm: 5)),
            ).toJson()
            // Strip the new key, as a pre-0107 record would look.
            ..remove('decimalEntry');
      final restored = SessionSnapshot.fromJson(json);
      expect(restored.session.decimalEntry, isFalse);
      expect(restored.current!.shots.single.tenth, isNull);
    });
  });
}
