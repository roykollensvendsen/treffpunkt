// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Shared record fixtures: one canonical SessionRecord / FeltSessionRecord
// factory instead of a private copy in every test file. Each parameter has a
// harmless default, so a test states only the fields it asserts on.
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// A ring-program [SessionRecord] fixture.
///
/// [inner] is the record's `innerTens`; [payload] defaults to the minimal
/// `{'id': id}` map the queue/repository tests round-trip.
SessionRecord sessionRecord({
  String id = 's1',
  String program = '25 m NAIS fin',
  int total = 0,
  int maxTotal = 600,
  int inner = 0,
  DateTime? capturedAt,
  String? placeLabel,
  double? latitude,
  double? longitude,
  String? weaponName,
  Map<String, dynamic>? payload,
  String? competitionId,
}) => SessionRecord(
  id: id,
  program: program,
  capturedAt: capturedAt,
  placeLabel: placeLabel,
  latitude: latitude,
  longitude: longitude,
  weaponName: weaponName,
  total: total,
  maxTotal: maxTotal,
  innerTens: inner,
  payload: payload ?? <String, dynamic>{'id': id},
  competitionId: competitionId,
);

/// A finished-felt-round [FeltSessionRecord] fixture.
///
/// The snapshot holds [holdCount] holds with a single [shot] on the first one
/// (the remaining holds empty) — the smallest round the felt tests score,
/// list, sync and back up.
FeltSessionRecord feltSessionRecord({
  required DateTime capturedAt,
  String id = 'f1',
  FeltShooterGroup group = FeltShooterGroup.one,
  int currentHold = 0,
  int holdCount = 1,
  FeltPlacedShot shot = const FeltPlacedShot(
    dx: 1,
    dy: 1,
    figureIndex: 0,
    inner: true,
  ),
  String? competitionId,
  String? courseId,
}) => FeltSessionRecord(
  id: id,
  capturedAt: capturedAt,
  competitionId: competitionId,
  session: FeltSessionSnapshot(
    group: group,
    courseId: courseId,
    currentHold: currentHold,
    holds: <List<FeltPlacedShot>>[
      <FeltPlacedShot>[shot],
      for (var i = 1; i < holdCount; i++) const <FeltPlacedShot>[],
    ],
  ),
);
