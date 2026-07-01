// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the NorgesFelt 2026 course preview (specs 0068/0079): all 8
// holds render as one composed picture with their figure names.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';

void main() {
  testWidgets('shows all 8 composed holds with their figures (spec 0079)', (
    tester,
  ) async {
    // A tall viewport so the lazy list builds every hold.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeltCourseScreen())),
    );
    await tester.pumpAndSettle();

    for (var n = 1; n <= 8; n++) {
      expect(find.byKey(feltHoldCardKey(n)), findsOneWidget);
    }
    // Each hold is drawn as one composed picture.
    expect(find.byType(FeltHoldArtView), findsNWidgets(8));
    // The course can be shot (spec 0080).
    expect(find.byKey(feltShootButtonKey), findsOneWidget);
    // The figure names are listed under each hold.
    expect(find.textContaining('Hare'), findsWidgets);
    expect(find.textContaining('Ulvehode'), findsWidgets);
    expect(find.textContaining('Hold 1'), findsOneWidget);
    expect(find.textContaining('Hold 8'), findsOneWidget);
  });

  test(
    'holds are coloured black / green / red as on the course (spec 0078)',
    () {
      FeltHoldColour colourOf(int number) =>
          norgesfelt2026.firstWhere((h) => h.number == number).colour;
      expect(colourOf(1), FeltHoldColour.black);
      expect(colourOf(2), FeltHoldColour.green);
      expect(colourOf(3), FeltHoldColour.red);
      expect(colourOf(4), FeltHoldColour.black);
      expect(colourOf(5), FeltHoldColour.green);
      expect(colourOf(6), FeltHoldColour.red);
      expect(colourOf(7), FeltHoldColour.black);
      expect(colourOf(8), FeltHoldColour.green);
    },
  );
}
