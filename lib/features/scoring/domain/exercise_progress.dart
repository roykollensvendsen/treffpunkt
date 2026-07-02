// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// One completed session's result for the progress chart (spec 0090): when it
/// was shot and its points and inner-hit count. Ring sessions map total /
/// inner tens here; felt rounds map tally points / inner.
@immutable
class ProgressSample {
  /// Creates a sample.
  const ProgressSample({
    required this.capturedAt,
    required this.points,
    required this.inner,
  });

  /// When the session was shot, or null when no date was recorded.
  final DateTime? capturedAt;

  /// The session's total points.
  final int points;

  /// The session's inner-hit count (inner tens / innertreff).
  final int inner;
}

/// One point of the plotted series (spec 0090).
@immutable
class ProgressEntry {
  /// Creates an entry.
  const ProgressEntry({required this.points, required this.inner});

  /// The session's total points.
  final int points;

  /// The session's inner-hit count.
  final int inner;
}

/// The chart's series for one exercise (spec 0090): the dated [samples] in
/// chronological order, oldest first — the x-axis is simply this order, no
/// time axis. Undated samples are dropped: their position is unknowable.
List<ProgressEntry> progressSeries(Iterable<ProgressSample> samples) {
  final dated = <ProgressSample>[
    for (final sample in samples)
      if (sample.capturedAt != null) sample,
  ]..sort((a, b) => a.capturedAt!.compareTo(b.capturedAt!));
  return List<ProgressEntry>.unmodifiable(<ProgressEntry>[
    for (final sample in dated)
      ProgressEntry(points: sample.points, inner: sample.inner),
  ]);
}
