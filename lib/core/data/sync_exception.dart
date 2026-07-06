// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// The shared base of the per-feature cloud-sync exceptions
/// (`SessionSyncException`, `FeltSyncException`, `CompetitionSyncException`,
/// `ForumException`).
///
/// Each of them wraps the underlying [cause] — e.g. a `PostgrestException`, a
/// `TimeoutException` or a plain message — so a caller can tell a genuine
/// failure apart from an empty account and surface a "couldn't reach the
/// cloud" notice. Catch sites keep catching the concrete subclasses; the base
/// only carries what they all share.
abstract class SyncException implements Exception {
  /// Creates an exception wrapping the underlying [cause].
  const SyncException(this.cause);

  /// The underlying error — e.g. a `PostgrestException`, a `TimeoutException`
  /// — or a message.
  final Object cause;

  @override
  String toString() => '$runtimeType: $cause';
}

/// Runs [task]; on any failure debug-prints `'<debugLabel>: <error>'` (debug
/// builds only) and rethrows the error wrapped by [wrap].
///
/// This is the one try/catch shape every Supabase repository repeats: surface
/// the raw error in debug so a missing table or a dropped connection is
/// diagnosable, and throw the feature's own [SyncException] so the UI can show
/// a notice instead of the failure masquerading as an empty account.
Future<T> guardSync<T>(
  Future<T> Function() task, {
  required String debugLabel,
  required Exception Function(Object cause) wrap,
}) async {
  try {
    return await task();
  } on Object catch (error) {
    if (!kReleaseMode) debugPrint('$debugLabel: $error');
    throw wrap(error);
  }
}
