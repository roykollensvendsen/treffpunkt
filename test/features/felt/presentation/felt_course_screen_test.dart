// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the NorgesFelt 2026 course preview (spec 0068): all 8 holds
// render with their figures.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_figure_painter.dart';

void main() {
  testWidgets('shows all 8 holds with their figures (spec 0068)', (
    tester,
  ) async {
    // A tall viewport so the lazy list builds every hold.
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: FeltCourseScreen()));
    await tester.pumpAndSettle();

    for (var n = 1; n <= 8; n++) {
      expect(find.byKey(feltHoldCardKey(n)), findsOneWidget);
    }
    // Figures are drawn (e.g. the traced animals and a circle).
    expect(find.byType(FeltFigureView), findsWidgets);
    expect(find.text('Ulvehode'), findsOneWidget);
    expect(find.text('Hare'), findsOneWidget);
    expect(find.text('C13'), findsWidgets);
    // Each hold's figure strip shows a scrollbar so it's clear it scrolls
    // (and can be dragged) on desktop/web (spec 0074).
    expect(find.byType(Scrollbar), findsWidgets);
  });
}
