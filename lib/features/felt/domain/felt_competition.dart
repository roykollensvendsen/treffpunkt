// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

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

/// The official course maximum for [group] (spec 0068, norgesfelt.no):
/// 80 points for Gruppe 1 (48 treff + 32 figur), 47 for Gruppe 2/3.
int feltCourseMaxPoints(FeltShooterGroup group) => switch (group) {
  FeltShooterGroup.one => 80,
  FeltShooterGroup.two || FeltShooterGroup.three => 47,
};
