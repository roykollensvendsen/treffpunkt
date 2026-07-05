// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the felt-competition program encoding (spec 0140).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

void main() {
  test('the group rides the program name, round-trip (spec 0140)', () {
    for (final group in FeltShooterGroup.values) {
      final program = feltCompetitionProgram(group);
      expect(program, contains('NorgesFelt'));
      expect(program, contains(group.label));
      expect(feltCompetitionGroup(program), group);
    }
  });

  test('a ring program is not a felt competition', () {
    expect(feltCompetitionGroup('10 m Luftpistol 60 skudd'), isNull);
    expect(feltCompetitionGroup('NorgesFelt-løype 2026'), isNull);
  });

  test('the official course maxima (spec 0068)', () {
    expect(feltCourseMaxPoints(FeltShooterGroup.one), 80);
    expect(feltCourseMaxPoints(FeltShooterGroup.two), 47);
  });
}
