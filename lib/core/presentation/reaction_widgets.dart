// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';

/// The emoji offered when reacting to a chat message or a forum post —
/// one palette for the whole app (specs 0052/0055).
const List<String> messageReactionPalette = <String>[
  '👍',
  '🎯',
  '🔥',
  '😂',
  '❤️',
  '👏',
  '😮',
  '😢',
];

/// Opens the emoji palette in a bottom sheet and resolves to the picked emoji,
/// or null when dismissed (specs 0052/0055). [emojiKeyFor] names each choice
/// for the screen's test finders.
Future<String?> showReactionPalette(
  BuildContext context, {
  Key Function(String emoji)? emojiKeyFor,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final emoji in messageReactionPalette)
              IconButton(
                key: emojiKeyFor?.call(emoji),
                onPressed: () => Navigator.of(sheetContext).pop(emoji),
                icon: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// One emoji's aggregated reactions on a message, as the [ReactionBar] shows
/// it. A pure view-model: the chat and forum screens each fold their own
/// reaction records into these, so their data models stay separate by design.
@immutable
class ReactionView {
  /// Creates the view of one emoji's reactions.
  const ReactionView({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.reactorNames,
  });

  /// The emoji reacted with.
  final String emoji;

  /// How many people gave this reaction.
  final int count;

  /// Whether the current user is one of them (accents the chip).
  final bool mine;

  /// The reactors' display names, for the who-reacted sheet (spec 0059).
  final List<String> reactorNames;
}

/// The reaction chips under a chat message or a forum post, plus an
/// add-reaction button (specs 0052/0055): tapping a chip toggles that emoji,
/// the add button opens the palette, and holding a chip lists who reacted
/// (spec 0059).
///
/// You react to OTHER people's messages, not your own: with [canReact] false
/// the chips are display-only and there is no add button — but holding still
/// shows the reactors.
class ReactionBar extends StatelessWidget {
  /// Creates the bar over the message's aggregated [reactions].
  const ReactionBar({
    required this.reactions,
    required this.onToggle,
    this.canReact = true,
    this.chipKeyFor,
    this.addKey,
    this.paletteKeyFor,
    super.key,
  });

  /// One entry per emoji reacted with, in display order.
  final List<ReactionView> reactions;

  /// Called with the emoji to toggle — from a chip tap or a palette pick.
  final void Function(String emoji) onToggle;

  /// Whether the current user may react here (false on their own message).
  final bool canReact;

  /// Names each emoji's chip for the screen's test finders.
  final Key Function(String emoji)? chipKeyFor;

  /// Names the add-reaction button for the screen's test finders.
  final Key? addKey;

  /// Names each palette choice for the screen's test finders.
  final Key Function(String emoji)? paletteKeyFor;

  Future<void> _openPalette(BuildContext context) async {
    final emoji = await showReactionPalette(
      context,
      emojiKeyFor: paletteKeyFor,
    );
    if (emoji != null) onToggle(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final reaction in reactions)
          InkWell(
            key: chipKeyFor?.call(reaction.emoji),
            onTap: canReact ? () => onToggle(reaction.emoji) : null,
            // Hold a reaction to see who reacted with it (spec 0059).
            onLongPress: () => showReactors(
              context,
              reaction.emoji,
              reaction.reactorNames,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: reaction.mine
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: reaction.mine
                    ? Border.all(color: theme.colorScheme.primary)
                    : null,
              ),
              child: Text(
                '${reaction.emoji} ${reaction.count}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        if (canReact)
          IconButton(
            key: addKey,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: 'Reager',
            onPressed: () => unawaited(_openPalette(context)),
            icon: const Icon(Icons.add_reaction_outlined),
          ),
      ],
    );
  }
}
