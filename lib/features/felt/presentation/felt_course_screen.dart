// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';

/// Key for the "shoot the course" button on the preview (spec 0080), for tests.
const Key feltShootButtonKey = ValueKey<String>('feltShoot');

/// Key for hold [number]'s card in the course preview (spec 0068), for tests.
Key feltHoldCardKey(int number) => ValueKey<String>('feltHold-$number');

/// A preview of the NorgesFelt 2026 field course (specs 0068/0079): the 8 holds
/// each drawn as one composed picture matching the official target sheet
/// (backing plates, figures to real relative scale, inner rings, and the black
/// separators between målgrupper). Recording/scoring come next.
class FeltCourseScreen extends StatelessWidget {
  /// Creates the course preview.
  const FeltCourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NorgesFelt-løype 2026')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '8 hold · innertreff på alle figurer · 10 sek skytetid · '
                      'maks 80/47 poeng. Hvert hold er tegnet som på den '
                      'offisielle skiva.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: feltShootButtonKey,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FeltRecordScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Skyt løypa'),
                ),
                const SizedBox(height: 8),
                for (final hold in norgesfelt2026)
                  Card(
                    key: feltHoldCardKey(hold.number),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Hold ${hold.number}  ·  ${hold.distance}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            hold.position,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FeltHoldArtView(art: _artFor(hold.number)),
                          const SizedBox(height: 8),
                          Text(
                            'Figurer: '
                            '${hold.figures.map((f) => f.name).join(', ')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The composed art for hold [number] (spec 0079).
FeltHoldArt _artFor(int number) =>
    norgesfelt2026Art.firstWhere((a) => a.number == number);
