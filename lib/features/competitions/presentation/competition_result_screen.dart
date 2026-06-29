// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';

/// Key for the "cannot show this result" message when a stored payload cannot
/// be rebuilt, used by tests (spec 0037).
const Key unreadableResultKey = ValueKey<String>('unreadableResult');

/// A read-only scorecard for **another** shooter's competition result (spec
/// 0037): every stage and series of the result behind a scoreboard row.
///
/// The full session is already on the client — each [CompetitionResult] carries
/// the session [CompetitionResult.payload] (a [SessionSnapshot]), readable by
/// every participant (spec 0010 RLS) — so this rebuilds and re-scores it with
/// no extra fetch, exactly as `SessionDetailScreen` does for one's own sessions
/// (spec 0026). The app bar is titled with the shooter's name. A payload that
/// cannot be rebuilt shows a graceful message instead of crashing.
class CompetitionResultScreen extends StatelessWidget {
  /// Creates the scorecard view for [result].
  const CompetitionResultScreen({required this.result, super.key});

  /// The scoreboard result to render.
  final CompetitionResult result;

  static const ScoringService _scoring = ScoringService();

  @override
  Widget build(BuildContext context) {
    final shooter = result.profile?.displayName ?? 'Ukjent skytter';
    final SessionSnapshot snapshot;
    try {
      snapshot = SessionSnapshot.fromJson(result.payload);
    } on Object {
      return Scaffold(
        appBar: AppBar(title: Text(shooter)),
        body: const SafeArea(
          child: _CenteredMessage(
            'Kan ikke vise dette resultatet',
            key: unreadableResultKey,
          ),
        ),
      );
    }
    final session = snapshot.session;
    return SessionScorecard(
      title: shooter,
      program: session.program,
      score: _scoring.scoreSession(session),
      metadata: session.metadata,
      weapon: session.weapon,
      seriesByStage: session.sealedSeriesByStage,
    );
  }
}

/// A centred, padded message (the unreadable-result state).
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
