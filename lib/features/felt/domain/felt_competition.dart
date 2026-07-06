// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:uuid/uuid.dart';

// NorgesFelt as a competition program (spec 0140).
//
// The group IS the program: the groups shoot different courses (Gruppe 1
// six shots per hold, Gruppe 2 five), so a fair competition is per group.
// Encoding the group in the program name locks it at creation with no
// schema change, and every place that shows the program shows the group.
const String _base = 'NorgesFelt-løype 2026';

/// The program name for a felt competition locked to [group].
String feltCompetitionProgram(FeltShooterGroup group) =>
    '$_base (${group.label})';

/// The locked group of a felt-competition [program] name, or `null` when
/// the program is not a felt competition.
FeltShooterGroup? feltCompetitionGroup(String program) {
  for (final group in FeltShooterGroup.values) {
    if (program == feltCompetitionProgram(group)) return group;
  }
  return null;
}

/// The competition-result id for the felt round [roundId] (spec 0140).
///
/// Felt round ids are radix-36 timestamps minted by the recorder, but the
/// backend's `competition_results.id` column is a Postgres `uuid` — submitting
/// the round id verbatim was rejected with 22P02 («invalid input syntax for
/// type uuid»), so felt results never reached the scoreboard. (The in-memory
/// repository accepts any string, which is why the unit suite never caught
/// it.) Mapping the round id through a *deterministic* UUIDv5 fixes the type
/// without a schema change and keeps the submission idempotent: the durable
/// upload queue (spec 0144) may retry a round many times, and the same round
/// must always yield the same result id so retries upsert instead of
/// duplicating.
String feltCompetitionResultId(String roundId) =>
    const Uuid().v5(Namespace.url.value, 'treffpunkt:felt-result:$roundId');

/// The official course maximum for [group] (spec 0068, norgesfelt.no):
/// 80 points for Gruppe 1 (48 treff + 32 figur), 47 for Gruppe 2/3.
int feltCourseMaxPoints(FeltShooterGroup group) => switch (group) {
  FeltShooterGroup.one => 80,
  FeltShooterGroup.two || FeltShooterGroup.three => 47,
};
