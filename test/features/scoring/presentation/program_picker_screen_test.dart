// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the program picker.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';

void main() {
  testWidgets('lists programs and opens the series screen on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProgramPickerScreen()),
      ),
    );

    expect(find.text('10 m Air Rifle'), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsOneWidget);
    expect(find.text('10 m Air Pistol'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('program-25 m Finpistol')),
    );
    await tester.pumpAndSettle();

    // Navigated to the series screen for the chosen program's target.
    expect(find.byKey(seriesTargetKey), findsOneWidget);
    expect(find.text('25 m Finpistol'), findsWidgets);
  });
}
