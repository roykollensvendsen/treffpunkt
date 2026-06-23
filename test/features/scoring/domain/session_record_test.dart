// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for SessionRecord (spec 0024): mapping a completed session + its
// score to the queryable columns plus a loss-free payload.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

const TargetGeometry _geo = TargetGeometry.pistol25mPrecision();
const Shot _centre = Shot(dxMm: 0, dyMm: 0);

// A 40 mm off-centre shot — ring 9 on the precision face, not an inner ten — so
// total and inner-ten counts differ from an all-centre series.
const Shot _nine = Shot(dxMm: 40, dyMm: 0);

// Two stages, each one series of two shots.
const ProgramDefinition _program = ProgramDefinition(
  name: 'Test',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: _geo,
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
    StageDefinition(
      name: 'B',
      geometry: _geo,
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
  ],
);

Series _series(Shot a, Shot b) =>
    Series(geometry: _geo, capacity: 2).placeShot(a).placeShot(b);

final Weapon _pistol = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '.22',
    label: 'Finpistol',
  ),
  id: 'p1',
  name: 'My pistol',
);

const ScoringService _scoring = ScoringService();

void main() {
  test('maps a completed session to the queryable columns and payload', () {
    // One inner ten + one ring-9 in stage A, two inner tens in stage B.
    final session = Session.start(
      _program,
      metadata: SessionMetadata(
        capturedAt: DateTime(2026, 6, 21, 14, 30),
        place: const Place(
          label: 'Løvenskiold',
          latitude: 59.9,
          longitude: 10.7,
        ),
      ),
      weapon: _pistol,
    ).sealSeries(_series(_centre, _nine)).sealSeries(_series(_centre, _centre));
    final score = _scoring.scoreSession(session);

    final record = SessionRecord.fromSession(session, score, id: 'abc-123');

    expect(record.id, 'abc-123');
    expect(record.program, 'Test');
    expect(record.capturedAt, DateTime(2026, 6, 21, 14, 30));
    expect(record.placeLabel, 'Løvenskiold');
    expect(record.latitude, 59.9);
    expect(record.longitude, 10.7);
    expect(record.weaponName, 'My pistol');
    // Stage A: 10 + 9 = 19, 1 inner ten. Stage B: 20, 2 inner tens. Max 40.
    expect(record.total, score.total);
    expect(record.total, 39);
    expect(record.maxTotal, 40);
    expect(record.innerTens, 3);

    // The payload is the lossless snapshot of the completed session: it equals
    // the snapshot's own JSON (with the id and no in-progress series).
    expect(record.payload['id'], 'abc-123');
    expect(record.payload['current'], isNull);
    expect(
      record.payload,
      SessionSnapshot(session: session, id: 'abc-123').toJson(),
    );
  });

  test('maps a session with no metadata and no weapon to null fields', () {
    final session = Session.start(_program)
        .sealSeries(_series(_centre, _centre))
        .sealSeries(_series(_centre, _centre));
    final score = _scoring.scoreSession(session);

    final record = SessionRecord.fromSession(session, score, id: 'no-meta');

    expect(record.capturedAt, isNull);
    expect(record.placeLabel, isNull);
    expect(record.latitude, isNull);
    expect(record.longitude, isNull);
    expect(record.weaponName, isNull);
    // All centre: 4 tens = 40, all inner tens.
    expect(record.total, 40);
    expect(record.maxTotal, 40);
    expect(record.innerTens, 4);
    expect(record.payload['id'], 'no-meta');
  });
}
