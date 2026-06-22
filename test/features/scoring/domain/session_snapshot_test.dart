// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the lossless JSON round-trip of an in-progress recording
// (spec 0009): program by name, weapon, metadata, sealed series and the
// partially-filled current series — with geometry rebuilt from the catalogue.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

const Shot _centre = Shot(dxMm: 0, dyMm: 0);
const Shot _off = Shot(dxMm: 1.5, dyMm: -2.25);

final Weapon _weapon = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '.22 LR',
    label: '.22 LR',
  ),
  id: 'w1',
  name: 'My Pardini',
  make: 'Pardini',
);

final SessionMetadata _metadata = SessionMetadata(
  capturedAt: DateTime(2026, 6, 21, 14, 30),
  place: const Place(label: 'Løvenskiold', latitude: 59.9, longitude: 10.7),
);

// Drives a snapshot through real JSON encoding/decoding, as the store does.
SessionSnapshot roundTrip(SessionSnapshot snapshot) => SessionSnapshot.fromJson(
  jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
);

void main() {
  test('a fresh empty recording round-trips', () {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final snapshot = SessionSnapshot(
      session: session,
      current: session.newSeries(),
    );
    expect(roundTrip(snapshot), snapshot);
  });

  test('a partially-filled current series round-trips with its shots', () {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final current = session.newSeries()!.placeShot(_centre).placeShot(_off);
    final snapshot = SessionSnapshot(session: session, current: current);

    final restored = roundTrip(snapshot);
    expect(restored, snapshot);
    expect(restored.current!.placedCount, 2);
    expect(restored.current!.capacity, 10);
    expect(restored.current!.shots[1].dxMm, 1.5);
    expect(restored.current!.shots[1].dyMm, -2.25);
  });

  test('weapon and metadata round-trip when present', () {
    final session = Session.start(
      ProgramCatalogue.finpistol25m,
      weapon: _weapon,
      metadata: _metadata,
    );
    final snapshot = SessionSnapshot(
      session: session,
      current: session.newSeries(),
    );

    final restored = roundTrip(snapshot);
    expect(restored, snapshot);
    expect(restored.session.weapon, _weapon);
    expect(restored.session.metadata, _metadata);
  });

  test('metadata with a place lacking coordinates round-trips', () {
    final metadata = SessionMetadata(
      capturedAt: DateTime(2026, 6, 21, 14, 30),
      place: const Place(label: 'Min bane'),
    );
    final session = Session.start(
      ProgramCatalogue.airRifle10m,
      metadata: metadata,
    );
    final snapshot = SessionSnapshot(
      session: session,
      current: session.newSeries(),
    );

    final restored = roundTrip(snapshot);
    expect(restored, snapshot);
    expect(restored.session.metadata!.place!.latitude, isNull);
    expect(restored.session.metadata!.place!.longitude, isNull);
  });

  test('weapon and metadata are null when absent', () {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final snapshot = SessionSnapshot(
      session: session,
      current: session.newSeries(),
    );

    final restored = roundTrip(snapshot);
    expect(restored.session.weapon, isNull);
    expect(restored.session.metadata, isNull);
  });

  test('a multi-stage program with sealed series round-trips', () {
    // Finpistol: two faces (presisjon rings 1-10, duell rings 5-10), 6 series
    // of 5 each. Seal the whole first stage and one series of the second.
    var session = Session.start(ProgramCatalogue.finpistol25m, weapon: _weapon);
    for (var i = 0; i < 6; i++) {
      var series = session.newSeries()!;
      for (var s = 0; s < 5; s++) {
        series = series.placeShot(_centre);
      }
      session = session.sealSeries(series);
    }
    // Now on the duell face; seal one series and leave a partial current.
    var duell = session.newSeries()!;
    for (var s = 0; s < 5; s++) {
      duell = duell.placeShot(_centre);
    }
    session = session.sealSeries(duell);
    final current = session.newSeries()!.placeShot(_off);
    final snapshot = SessionSnapshot(session: session, current: current);

    final restored = roundTrip(snapshot);
    expect(restored, snapshot);
    expect(restored.session.sealedSeriesByStage[0], hasLength(6));
    expect(restored.session.sealedSeriesByStage[1], hasLength(1));
    expect(restored.current!.placedCount, 1);
    // The duell face geometry was rebuilt from the catalogue, not the JSON.
    expect(restored.current!.geometry.lowestRingValue, 5);
  });

  test('a completed session round-trips with no current series', () {
    var session = Session.start(ProgramCatalogue.airRifle10m);
    var series = session.newSeries()!;
    for (var s = 0; s < 10; s++) {
      series = series.placeShot(_centre);
    }
    session = session.sealSeries(series);
    expect(session.isComplete, isTrue);

    final snapshot = SessionSnapshot(session: session);
    final restored = roundTrip(snapshot);
    expect(restored, snapshot);
    expect(restored.current, isNull);
    expect(restored.session.isComplete, isTrue);
  });

  test('geometry is rebuilt from the catalogue, never read from JSON', () {
    final session = Session.start(ProgramCatalogue.airRifle10m);
    final snapshot = SessionSnapshot(
      session: session,
      current: session.newSeries(),
    );
    // The JSON carries no geometry at all.
    final json = snapshot.toJson();
    expect(json.toString(), isNot(contains('ringOuterDiametersMm')));

    final restored = SessionSnapshot.fromJson(json);
    final stageGeometry = ProgramCatalogue.airRifle10m.stages.first.geometry;
    expect(restored.current!.geometry.name, stageGeometry.name);
    expect(
      restored.current!.geometry.ringOuterDiametersMm,
      stageGeometry.ringOuterDiametersMm,
    );
  });

  test('an unknown program name throws a FormatException', () {
    final json = <String, dynamic>{
      'program': 'No Such Program',
      'weapon': null,
      'metadata': null,
      'sealedSeriesByStage': <dynamic>[],
      'current': null,
    };
    expect(
      () => SessionSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
