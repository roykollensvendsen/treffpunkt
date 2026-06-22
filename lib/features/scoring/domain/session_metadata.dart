// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';

/// When and where a session was shot (ADR-0012).
///
/// A pure value type: [capturedAt] is supplied by the caller — the domain never
/// reads the wall clock — and [place] is optional. Compared by value.
@immutable
class SessionMetadata {
  /// Creates metadata captured at [capturedAt] with an optional [place].
  const SessionMetadata({required this.capturedAt, this.place});

  /// The moment the session was set up, as supplied by the caller.
  final DateTime capturedAt;

  /// Where the session was shot, or `null` when not recorded.
  final Place? place;

  /// A copy with the given fields replaced; unspecified fields are kept.
  SessionMetadata copyWith({DateTime? capturedAt, Place? place}) {
    return SessionMetadata(
      capturedAt: capturedAt ?? this.capturedAt,
      place: place ?? this.place,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionMetadata &&
      other.capturedAt == capturedAt &&
      other.place == place;

  @override
  int get hashCode => Object.hash(capturedAt, place);
}
