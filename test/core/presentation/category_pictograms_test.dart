// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the ammunition category pictograms (spec 0154).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/category_pictograms.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  testWidgets('the pellet paints at its given size', (tester) async {
    await pump(tester, const PelletPictogram(size: 40));
    // A SizedBox of the requested side wraps the painter.
    final box = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(PelletPictogram),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, 40);
    expect(box.height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cartridge paints at its given size', (tester) async {
    await pump(tester, const CartridgePictogram(size: 40));
    final box = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(CartridgePictogram),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, 40);
    expect(box.height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both fall back to the ambient icon size', (tester) async {
    await pump(
      tester,
      const IconTheme(
        data: IconThemeData(size: 26),
        child: Row(children: [PelletPictogram(), CartridgePictogram()]),
      ),
    );
    for (final finder in [
      find.byType(PelletPictogram),
      find.byType(CartridgePictogram),
    ]) {
      final box = tester.widget<SizedBox>(
        find.descendant(of: finder, matching: find.byType(SizedBox)).first,
      );
      expect(box.width, 26);
    }
    expect(tester.takeException(), isNull);
  });

  test('the outlines are closed polygons within the unit box', () {
    final polygons = <List<Offset>>[
      PelletPictogram.head,
      PelletPictogram.skirt,
      CartridgePictogram.caseAndRim,
      CartridgePictogram.bullet,
    ];
    for (final points in polygons) {
      expect(points.length, greaterThanOrEqualTo(3));
      for (final p in points) {
        expect(p.dx, inInclusiveRange(0, 1));
        expect(p.dy, inInclusiveRange(0, 1));
      }
    }
    // The pellet is a touch taller than wide; the cartridge tall and slim.
    expect(PelletPictogram.aspect, closeTo(0.856, 0.001));
    expect(CartridgePictogram.aspect, lessThan(0.5));
  });
}
