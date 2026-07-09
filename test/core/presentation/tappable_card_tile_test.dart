// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the shared picker navigation tile (specs 0084, 0158).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/tappable_card_tile.dart';

void main() {
  Widget host(TappableCardTile tile) => MaterialApp(home: Scaffold(body: tile));

  testWidgets('renders a leading glyph when given one (spec 0158)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TappableCardTile(
          tileKey: const ValueKey<String>('t'),
          leading: const Icon(Icons.star, key: ValueKey<String>('lead')),
          title: 'Tittel',
          subtitle: 'Undertittel',
          semanticsLabel: 'Tittel, Undertittel',
          onTap: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('lead')), findsOneWidget);
  });

  testWidgets('renders no leading by default', (tester) async {
    await tester.pumpWidget(
      host(
        TappableCardTile(
          tileKey: const ValueKey<String>('t'),
          title: 'Tittel',
          subtitle: 'Undertittel',
          semanticsLabel: 'Tittel, Undertittel',
          onTap: () {},
        ),
      ),
    );
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.leading, isNull);
  });
}
