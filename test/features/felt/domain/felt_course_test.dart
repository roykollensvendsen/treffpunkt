// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the felt course values (spec 0145): the NorgesFelt Asker+
// course, course lookup by id and per-course max points.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

void main() {
  test('Asker+ is the 2026 course plus holds 9 and 10 (spec 0145)', () {
    expect(askerPlusCourse.holds, hasLength(10));
    // Holds 1–8 are the very same definitions — no forked copies.
    for (var i = 0; i < 8; i++) {
      expect(askerPlusCourse.holds[i], same(norgesfelt2026[i]));
    }
    expect(askerPlusCourse.holds[8].number, 9);
    expect(askerPlusCourse.holds[9].number, 10);
  });

  test('hold 9 is six hexagons (spec 0145)', () {
    final figures = askerPlusCourse.holds[8].figures;
    expect(figures, hasLength(6));
    for (final figure in figures) {
      expect(figure.type, FeltFigureType.hexagon);
    }
  });

  test('hold 10 is three stolper, the big oval and the owl (spec 0145)', () {
    final figures = askerPlusCourse.holds[9].figures;
    expect(figures, hasLength(5));
    expect(
      figures.take(3).map((f) => f.type),
      everyElement(FeltFigureType.stripe),
    );
    expect(figures[3].type, FeltFigureType.oval);
    expect(figures[4].type, FeltFigureType.owl);
    expect(figures[4].name, 'Ugle');
  });

  test('courses resolve by id, unknown defaults to 2026 (spec 0145)', () {
    expect(feltCourseById(norgesfelt2026Course.id), same(norgesfelt2026Course));
    expect(feltCourseById(askerPlusCourse.id), same(askerPlusCourse));
    expect(feltCourseById(null), same(norgesfelt2026Course));
    expect(feltCourseById('no-such-course'), same(norgesfelt2026Course));
  });

  test('2026 keeps its official maxima (specs 0068/0145)', () {
    expect(norgesfelt2026Course.maxPoints(FeltShooterGroup.one), 80);
    expect(norgesfelt2026Course.maxPoints(FeltShooterGroup.two), 47);
  });

  test('Asker+ maxima are computed from the scoring rules (spec 0145)', () {
    // Gruppe 1: 6 shots × 10 holds = 60 treff + Σ min(6, figures) = 43 figur.
    expect(askerPlusCourse.maxPoints(FeltShooterGroup.one), 103);
    // Gruppe 2: 5 × 10 = 50 treff + Σ min(5, figures) = 40 figur.
    expect(askerPlusCourse.maxPoints(FeltShooterGroup.two), 90);
  });

  test('program names and record keys carry course and group (spec 0145)', () {
    expect(
      askerPlusCourse.programName(FeltShooterGroup.one),
      'NorgesFelt Asker+ (Gruppe 1)',
    );
    expect(
      askerPlusCourse.recordKey(FeltShooterGroup.two),
      'NorgesFelt Asker+ · Gruppe 2',
    );
    // The 2026 encodings are unchanged (specs 0140/0143).
    expect(
      norgesfelt2026Course.programName(FeltShooterGroup.two),
      'NorgesFelt-løype 2026 (Gruppe 2)',
    );
    expect(
      norgesfelt2026Course.recordKey(FeltShooterGroup.one),
      'NorgesFelt-løype 2026 · Gruppe 1',
    );
  });
}
