// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:uuid/uuid.dart';

// NorgesFelt as a competition program (specs 0140/0145).
//
// The course and group ARE the program: the groups shoot different rounds
// (Gruppe 1 six shots per hold, Gruppe 2 five) and the courses differ, so a
// fair competition is per course + group. Encoding both in the program name
// locks them at creation with no schema change, and every place that shows
// the program shows the course and group.

/// The program name for a felt competition locked to [course] and [group].
String feltCompetitionProgram(FeltCourse course, FeltShooterGroup group) =>
    course.programName(group);

/// The locked course and group of a felt-competition [program] name, or
/// `null` when the program is not a felt competition (spec 0145). Pre-0145
/// program strings carry the 2026 course name and parse unchanged.
({FeltCourse course, FeltShooterGroup group})? feltCompetitionCourseAndGroup(
  String program,
) {
  for (final course in feltCourses) {
    for (final group in FeltShooterGroup.values) {
      if (program == course.programName(group)) {
        return (course: course, group: group);
      }
    }
  }
  return null;
}

/// The locked group of a felt-competition [program] name, or `null` when
/// the program is not a felt competition.
FeltShooterGroup? feltCompetitionGroup(String program) =>
    feltCompetitionCourseAndGroup(program)?.group;

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
