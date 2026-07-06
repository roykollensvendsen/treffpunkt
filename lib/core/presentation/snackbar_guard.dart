// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Runs [task] and shows a snackbar with [failureMessage] if it throws,
/// returning whether it succeeded so the caller can chain follow-up work
/// (navigation, provider invalidation) on success only.
///
/// The [ScaffoldMessenger] is captured *before* the `await`, so the notice
/// still appears when the triggering widget is gone by the time the task
/// fails — the whole point of the pattern this replaces.
///
/// By default every thrown object is caught. Narrow the guard to one failure
/// type by giving [E] explicitly — anything else is rethrown untouched:
///
/// ```dart
/// final ok = await guardWithSnackBar<CompetitionSyncException>(
///   context,
///   task: () => repository.deleteCompetition(id),
///   failureMessage: 'Kunne ikke slette konkurransen.',
/// );
/// if (ok) ref.invalidate(myCompetitionsProvider);
/// ```
Future<bool> guardWithSnackBar<E extends Object>(
  BuildContext context, {
  required Future<void> Function() task,
  required String failureMessage,
}) async {
  // Captured before the await so no BuildContext is used across the gap.
  final messenger = ScaffoldMessenger.of(context);
  try {
    await task();
    return true;
  } on Object catch (error) {
    if (error is! E) rethrow;
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    return false;
  }
}
