// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// A result submitted to a competition (spec 0012): a completed session's
/// rolled-up score, on the competition's scoreboard.
///
/// Keyed by the session [id], so submitting the same session twice is a no-op
/// (the durable upload queue can retry safely). The submitter's [profile] is
/// attached separately for the scoreboard when known.
@immutable
class CompetitionResult {
  /// Creates a result.
  const CompetitionResult({
    required this.id,
    required this.competitionId,
    required this.program,
    required this.total,
    required this.maxTotal,
    required this.innerTens,
    required this.payload,
    this.userId,
    this.capturedAt,
    this.profile,
    this.createdAt,
  });

  /// Builds the result to submit for a completed [record], for [competitionId].
  ///
  /// The submitter's [userId] is optional — the database defaults it to
  /// `auth.uid()`, so it is not sent on submit; it is filled when read back.
  factory CompetitionResult.fromSessionRecord(
    SessionRecord record, {
    required String competitionId,
    String? userId,
  }) => CompetitionResult(
    id: record.id,
    competitionId: competitionId,
    userId: userId,
    program: record.program,
    total: record.total,
    maxTotal: record.maxTotal,
    innerTens: record.innerTens,
    capturedAt: record.capturedAt,
    payload: record.payload,
  );

  /// Reads a result from a `competition_results` row (snake_case columns).
  factory CompetitionResult.fromJson(Map<String, dynamic> json) {
    final capturedAt = json['captured_at'] as String?;
    final createdAt = json['created_at'] as String?;
    return CompetitionResult(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String?,
      program: json['program'] as String,
      total: (json['total'] as num).toInt(),
      maxTotal: (json['max_total'] as num).toInt(),
      innerTens: (json['inner_tens'] as num).toInt(),
      capturedAt: capturedAt == null ? null : parseWireTime(capturedAt),
      payload: json['payload'] as Map<String, dynamic>,
      createdAt: createdAt == null ? null : parseWireTime(createdAt),
    );
  }

  /// The result id (= the submitted session's id).
  final String id;

  /// The competition this result was submitted to.
  final String competitionId;

  /// The submitter's auth user id, or `null` before it is read back.
  final String? userId;

  /// The program shot (the catalogue name).
  final String program;

  /// The rolled-up total score.
  final int total;

  /// The maximum possible total for the program.
  final int maxTotal;

  /// The number of inner tens (X).
  final int innerTens;

  /// When the session was shot, or `null`.
  final DateTime? capturedAt;

  /// The lossless session snapshot (for re-scoring a detail view).
  final Map<String, dynamic> payload;

  /// The submitter's profile (name/avatar), attached for the scoreboard.
  final Profile? profile;

  /// When the row was created server-side, or `null` before it is read back.
  final DateTime? createdAt;

  /// The columns a client sends to submit a result.
  ///
  /// `user_id` is omitted — it defaults to `auth.uid()` in the database, so a
  /// shooter cannot submit a result as someone else.
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'competition_id': competitionId,
    'program': program,
    'total': total,
    'max_total': maxTotal,
    'inner_tens': innerTens,
    'captured_at': capturedAt?.toIso8601String(),
    'payload': payload,
  };

  /// A copy of this result stamped with the submitter's [userId].
  CompetitionResult withUser(String? userId) => CompetitionResult(
    id: id,
    competitionId: competitionId,
    userId: userId,
    program: program,
    total: total,
    maxTotal: maxTotal,
    innerTens: innerTens,
    capturedAt: capturedAt,
    payload: payload,
    profile: profile,
    createdAt: createdAt,
  );

  /// A copy of this result with [profile] attached.
  CompetitionResult withProfile(Profile? profile) => CompetitionResult(
    id: id,
    competitionId: competitionId,
    userId: userId,
    program: program,
    total: total,
    maxTotal: maxTotal,
    innerTens: innerTens,
    capturedAt: capturedAt,
    payload: payload,
    profile: profile,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is CompetitionResult &&
      other.id == id &&
      other.competitionId == competitionId &&
      other.userId == userId &&
      other.program == program &&
      other.total == total &&
      other.maxTotal == maxTotal &&
      other.innerTens == innerTens &&
      other.capturedAt == capturedAt &&
      other.profile == profile &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    competitionId,
    userId,
    program,
    total,
    maxTotal,
    innerTens,
    capturedAt,
    profile,
    createdAt,
  );
}
