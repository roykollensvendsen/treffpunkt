// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the shared reaction primitives of the competition chat and
// the forum (specs 0052/0055/0059): the emoji palette, and a ReactionBar over
// per-emoji view-models that toggles on tap, opens the palette from the add
// button, and lists the reactors on a long press. On your own message the
// chips are display-only and there is no add button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/reaction_widgets.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';

Key _chipKey(String emoji) => ValueKey<String>('chip-$emoji');
Key _paletteKey(String emoji) => ValueKey<String>('palette-$emoji');
const Key _addKey = ValueKey<String>('add');

Widget _host({
  required List<ReactionView> reactions,
  required void Function(String) onToggle,
  bool canReact = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ReactionBar(
        reactions: reactions,
        onToggle: onToggle,
        canReact: canReact,
        chipKeyFor: _chipKey,
        addKey: _addKey,
        paletteKeyFor: _paletteKey,
      ),
    ),
  );
}

void main() {
  const thumbsUp = ReactionView(
    emoji: '👍',
    count: 2,
    mine: true,
    reactorNames: ['Kari', 'Ola'],
  );
  const fire = ReactionView(
    emoji: '🔥',
    count: 1,
    mine: false,
    reactorNames: ['Kari'],
  );

  testWidgets('shows one chip per reaction with emoji and count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(reactions: const [thumbsUp, fire], onToggle: (_) {}),
    );

    expect(find.text('👍 2'), findsOneWidget);
    expect(find.text('🔥 1'), findsOneWidget);
    expect(find.byKey(_chipKey('👍')), findsOneWidget);
    expect(find.byKey(_chipKey('🔥')), findsOneWidget);
  });

  testWidgets('tapping a chip toggles that emoji', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      _host(reactions: const [thumbsUp, fire], onToggle: toggled.add),
    );

    await tester.tap(find.byKey(_chipKey('🔥')));

    expect(toggled, ['🔥']);
  });

  testWidgets('the add button opens the palette; picking toggles', (
    tester,
  ) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      _host(reactions: const [], onToggle: toggled.add),
    );

    await tester.tap(find.byKey(_addKey));
    await tester.pumpAndSettle();

    for (final emoji in messageReactionPalette) {
      expect(find.byKey(_paletteKey(emoji)), findsOneWidget);
    }

    await tester.tap(find.byKey(_paletteKey('🎯')));
    await tester.pumpAndSettle();

    expect(toggled, ['🎯']);
  });

  testWidgets('dismissing the palette toggles nothing', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      _host(reactions: const [], onToggle: toggled.add),
    );

    await tester.tap(find.byKey(_addKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(toggled, isEmpty);
  });

  testWidgets('on your own message the chips are display-only', (
    tester,
  ) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      _host(
        reactions: const [thumbsUp],
        onToggle: toggled.add,
        canReact: false,
      ),
    );

    expect(find.byKey(_addKey), findsNothing);
    await tester.tap(find.byKey(_chipKey('👍')));
    expect(toggled, isEmpty);
  });

  testWidgets('holding a chip lists who reacted', (tester) async {
    await tester.pumpWidget(
      _host(reactions: const [thumbsUp], onToggle: (_) {}),
    );

    await tester.longPress(find.byKey(_chipKey('👍')));
    await tester.pumpAndSettle();

    expect(find.byKey(reactorsSheetKey), findsOneWidget);
    expect(find.text('Kari'), findsOneWidget);
    expect(find.text('Ola'), findsOneWidget);
  });

  testWidgets('holding works on your own message too', (tester) async {
    await tester.pumpWidget(
      _host(reactions: const [thumbsUp], onToggle: (_) {}, canReact: false),
    );

    await tester.longPress(find.byKey(_chipKey('👍')));
    await tester.pumpAndSettle();

    expect(find.byKey(reactorsSheetKey), findsOneWidget);
  });

  test('the shared palette is the eight agreed emoji', () {
    expect(messageReactionPalette, [
      '👍',
      '🎯',
      '🔥',
      '😂',
      '❤️',
      '👏',
      '😮',
      '😢',
    ]);
  });
}
