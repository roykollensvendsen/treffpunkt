// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the in-app user manual (spec 0050): the contents list shows
// every page; opening one renders its Markdown (loaded through the injected
// seam, with the licence comment stripped). No real assets needed.
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/help/domain/manual.dart';
import 'package:treffpunkt/features/help/presentation/help_providers.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';

Widget _app(ManualLoader loader) => ProviderScope(
  overrides: [manualLoaderProvider.overrideWithValue(loader)],
  child: const MaterialApp(home: HelpScreen()),
);

void main() {
  testWidgets('lists every manual page', (tester) async {
    await tester.pumpWidget(_app((_) async => ''));
    await tester.pumpAndSettle();

    for (final page in manualPages) {
      expect(find.byKey(manualPageTileKey(page.file)), findsOneWidget);
      expect(find.text(page.title), findsOneWidget);
    }
  });

  testWidgets('opening a page renders its markdown, licence comment stripped', (
    tester,
  ) async {
    const raw =
        '<!--\nSPDX-FileCopyrightText: 2026\n-->\n\n'
        '# Konkurranser\n\nDel en lenke; den som åpner den blir med.';
    await tester.pumpWidget(_app((_) async => raw));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(manualPageTileKey('competitions.md')));
    await tester.pumpAndSettle();

    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, startsWith('# Konkurranser'));
    expect(markdown.data, contains('Del en lenke'));
    expect(markdown.data, isNot(contains('SPDX')));
  });
}
