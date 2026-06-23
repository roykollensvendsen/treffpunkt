// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_score.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';

/// The uploadable form of one completed session (spec 0024).
///
/// A pure value type that pairs the few **queryable** fields a future result
/// list will sort and filter on — the [program] name, when and where it was
/// shot ([capturedAt] / [placeLabel] / [latitude] / [longitude]), the
/// [weaponName], and the rolled-up [total] / [maxTotal] / [innerTens] — with
/// the loss-free [payload] (the spec 0009 `SessionSnapshot.toJson()` map).
/// [id] is the stable client-generated upload key (ADR-0017): re-uploading the
/// same [id] is an idempotent upsert.
///
/// The id is supplied by the caller, not derived here, so this type stays pure
/// and deterministic.
@immutable
class SessionRecord {
  /// Creates a record with the given [id], queryable columns and [payload].
  const SessionRecord({
    required this.id,
    required this.program,
    required this.total,
    required this.maxTotal,
    required this.innerTens,
    required this.payload,
    this.capturedAt,
    this.placeLabel,
    this.latitude,
    this.longitude,
    this.weaponName,
  });

  /// Builds the uploadable record of a completed [session] with its [score].
  ///
  /// [id] is the recording's stable client-generated id. The queryable columns
  /// are read from the session's metadata, weapon and [score]; [payload] is the
  /// session's lossless snapshot (a completed session has no in-progress
  /// series, so `current` is `null`).
  factory SessionRecord.fromSession(
    Session session,
    SessionScore score, {
    required String id,
  }) {
    final metadata = session.metadata;
    final place = metadata?.place;
    return SessionRecord(
      id: id,
      program: session.program.name,
      capturedAt: metadata?.capturedAt,
      placeLabel: place?.label,
      latitude: place?.latitude,
      longitude: place?.longitude,
      weaponName: session.weapon?.name,
      total: score.total,
      maxTotal: score.maxTotal,
      innerTens: score.innerTens,
      payload: SessionSnapshot(session: session, id: id).toJson(),
    );
  }

  /// The stable client-generated id; the upload (upsert) key (ADR-0017).
  final String id;

  /// The program (discipline) name, e.g. `'10 m Air Pistol'`.
  final String program;

  /// When the session was shot, or `null` when no metadata was recorded.
  final DateTime? capturedAt;

  /// Human-readable place name, or `null` when no place was recorded.
  final String? placeLabel;

  /// Latitude in decimal degrees, or `null` when no coordinates are known.
  final double? latitude;

  /// Longitude in decimal degrees, or `null` when no coordinates are known.
  final double? longitude;

  /// The weapon's name, or `null` when no weapon was recorded.
  final String? weaponName;

  /// Sum of every stage's ring scores.
  final int total;

  /// The highest total the session could reach.
  final int maxTotal;

  /// Total inner tens across the session.
  final int innerTens;

  /// The lossless snapshot of the session (spec 0009 `SessionSnapshot.toJson`).
  final Map<String, dynamic> payload;
}
