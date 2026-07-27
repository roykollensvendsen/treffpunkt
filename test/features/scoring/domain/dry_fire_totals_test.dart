// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_totals.dart';

DryFireEntry _entry(DryFireDiscipline discipline, int pulls) => DryFireEntry(
  id: '$discipline-$pulls',
  recordedAt: DateTime.utc(2026, 7, 27),
  discipline: discipline,
  triggerPulls: pulls,
);

void main() {
  group('DryFireTotals (spec 0161)', () {
    test('empty log totals to zero everywhere', () {
      final totals = DryFireTotals.of(const []);
      expect(totals.forDiscipline(DryFireDiscipline.presisjon), 0);
      expect(totals.forDiscipline(DryFireDiscipline.duell), 0);
      expect(totals.grandTotal, 0);
      expect(totals.isEmpty, isTrue);
    });

    test('sums per discipline and overall across a mixed log', () {
      final totals = DryFireTotals.of([
        _entry(DryFireDiscipline.presisjon, 20),
        _entry(DryFireDiscipline.duell, 25),
        _entry(DryFireDiscipline.presisjon, 30),
      ]);
      expect(totals.forDiscipline(DryFireDiscipline.presisjon), 50);
      expect(totals.forDiscipline(DryFireDiscipline.duell), 25);
      expect(totals.grandTotal, 75);
      expect(totals.isEmpty, isFalse);
    });
  });
}
