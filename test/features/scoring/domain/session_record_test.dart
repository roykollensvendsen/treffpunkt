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

  // The JSON round-trip (spec 0025): a queued record is persisted as JSON and
  // read back identical, so a completed session survives a restart in the
  // queue.
  void expectRoundTrips(SessionRecord record) {
    final restored = SessionRecord.fromJson(record.toJson());
    expect(restored.id, record.id);
    expect(restored.program, record.program);
    expect(restored.capturedAt, record.capturedAt);
    expect(restored.placeLabel, record.placeLabel);
    expect(restored.latitude, record.latitude);
    expect(restored.longitude, record.longitude);
    expect(restored.weaponName, record.weaponName);
    expect(restored.total, record.total);
    expect(restored.maxTotal, record.maxTotal);
    expect(restored.innerTens, record.innerTens);
    expect(restored.payload, record.payload);
  }

  test('toJson/fromJson round-trips a full record losslessly', () {
    const record = SessionRecord(
      id: 'abc-123',
      program: '25 m Finpistol',
      total: 39,
      maxTotal: 40,
      innerTens: 3,
      placeLabel: 'Løvenskiold',
      latitude: 59.9,
      longitude: 10.7,
      weaponName: 'My pistol',
      payload: <String, dynamic>{
        'id': 'abc-123',
        'program': '25 m Finpistol',
        'current': null,
        'nested': <String, dynamic>{'value': 7},
      },
    );
    final full = SessionRecord(
      id: record.id,
      program: record.program,
      capturedAt: DateTime(2026, 6, 21, 14, 30),
      placeLabel: record.placeLabel,
      latitude: record.latitude,
      longitude: record.longitude,
      weaponName: record.weaponName,
      total: record.total,
      maxTotal: record.maxTotal,
      innerTens: record.innerTens,
      payload: record.payload,
    );

    expectRoundTrips(full);
    // The nested payload map survives intact.
    final restored = SessionRecord.fromJson(full.toJson());
    expect(
      (restored.payload['nested'] as Map<String, dynamic>)['value'],
      7,
    );
  });

  test('toJson/fromJson round-trips a minimal record (optionals null)', () {
    const minimal = SessionRecord(
      id: 'min',
      program: '10 m Air Pistol',
      total: 0,
      maxTotal: 100,
      innerTens: 0,
      payload: <String, dynamic>{'id': 'min'},
    );

    expectRoundTrips(minimal);
    final restored = SessionRecord.fromJson(minimal.toJson());
    expect(restored.capturedAt, isNull);
    expect(restored.placeLabel, isNull);
    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
    expect(restored.weaponName, isNull);
  });
}
