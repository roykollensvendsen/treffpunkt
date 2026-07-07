// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the felt-competition program encoding and the
// round-id → result-id mapping (spec 0140).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:uuid/uuid.dart';

void main() {
  test(
    'course and group ride the program name, round-trip (specs 0140/0145)',
    () {
      for (final course in feltCourses) {
        for (final group in FeltShooterGroup.values) {
          final program = feltCompetitionProgram(course, group);
          expect(program, contains(course.name));
          expect(program, contains(group.label));
          final parsed = feltCompetitionCourseAndGroup(program);
          expect(parsed?.course, same(course));
          expect(parsed?.group, group);
          expect(feltCompetitionGroup(program), group);
        }
      }
    },
  );

  test('legacy 2026 program strings still parse to 2026 (spec 0145)', () {
    final parsed = feltCompetitionCourseAndGroup(
      'NorgesFelt-løype 2026 (Gruppe 1)',
    );
    expect(parsed?.course, same(norgesfelt2026Course));
    expect(parsed?.group, FeltShooterGroup.one);
  });

  test('a ring program is not a felt competition', () {
    expect(feltCompetitionGroup('10 m Luftpistol 60 skudd'), isNull);
    expect(feltCompetitionGroup('NorgesFelt-løype 2026'), isNull);
    expect(feltCompetitionCourseAndGroup('NorgesFelt Asker+'), isNull);
  });

  group('feltCompetitionResultId (spec 0140)', () {
    test('is a canonical uuid — the results id column is `uuid`', () {
      // Felt round ids are radix-36 timestamps; submitting one verbatim as
      // the result id is rejected by Postgres (22P02), so the mapping must
      // always yield a canonical uuid.
      final id = feltCompetitionResultId('mc4rz9k2');
      expect(Uuid.isValidUUID(fromString: id), isTrue);
    });

    test('is stable for the same round — idempotent resubmission', () {
      // The durable queue (spec 0144) may retry a round many times; the
      // same round must always map to the same result id so the server
      // upsert stays idempotent.
      expect(
        feltCompetitionResultId('mc4rz9k2'),
        feltCompetitionResultId('mc4rz9k2'),
      );
    });

    test('differs across rounds', () {
      expect(
        feltCompetitionResultId('mc4rz9k2'),
        isNot(feltCompetitionResultId('mc4rz9k3')),
      );
    });
  });
}
