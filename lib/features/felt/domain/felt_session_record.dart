// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

/// A finished felt round saved to history (spec 0082): a stable [id], when it
/// was finished ([capturedAt]) and the round itself ([session]). The score is
/// computed from the snapshot via [tally], so there is one source of truth.
@immutable
class FeltSessionRecord {
  /// Creates a finished-round record.
  const FeltSessionRecord({
    required this.id,
    required this.capturedAt,
    required this.session,
  });

  /// Rebuilds a record from [json].
  factory FeltSessionRecord.fromJson(Map<String, dynamic> json) =>
      FeltSessionRecord(
        id: json['id'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        session: FeltSessionSnapshot.fromJson(
          json['session'] as Map<String, dynamic>,
        ),
      );

  /// Stable client-generated id.
  final String id;

  /// When the round was finished.
  final DateTime capturedAt;

  /// The finished round (group, per-hold placed shots).
  final FeltSessionSnapshot session;

  /// The scored tally of the round.
  FeltSessionTally get tally => FeltSessionTally(
    group: session.group,
    holds: <FeltHoldTally>[
      for (final hold in session.holds)
        FeltHoldTally(<FeltShot>[
          for (final s in hold)
            FeltShot(figureIndex: s.figureIndex, inner: s.inner),
        ]),
    ],
  );

  /// The round's total points.
  int get points => tally.points;

  /// Serialises this record.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'capturedAt': capturedAt.toIso8601String(),
    'session': session.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is FeltSessionRecord &&
      other.id == id &&
      other.capturedAt == capturedAt &&
      other.session == session;

  @override
  int get hashCode => Object.hash(id, capturedAt, session);
}
