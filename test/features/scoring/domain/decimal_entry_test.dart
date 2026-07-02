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

    test('false for the 5–10 faces', () {
      expect(
        const TargetGeometry.pistol25mRapid().supportsDecimalScore,
        isFalse,
      );
      expect(const TargetGeometry.airDuel10m().supportsDecimalScore, isFalse);
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

    test('a series on a 5–10 face has no decimal total', () {
      final series = Series(
        geometry: const TargetGeometry.pistol25mRapid(),
        capacity: 5,
      ).placeShot(const Shot(dxMm: 0, dyMm: 0));
      final score = scoring.scoreSeries(series);
      expect(score.decimalTotal, isNull);
      expect(score.shots.single.decimal, isNull);
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
