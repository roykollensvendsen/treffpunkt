// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/presentation/felt_figure_painter.dart';

/// Key for hold [number]'s card in the course preview (spec 0068), for tests.
Key feltHoldCardKey(int number) => ValueKey<String>('feltHold-$number');

/// A preview of the NorgesFelt 2026 field course (spec 0068): the 8 holds with
/// their figures drawn to real relative scale (recording/scoring come next).
class FeltCourseScreen extends StatelessWidget {
  /// Creates the course preview.
  const FeltCourseScreen({super.key});

  /// Pixels per centimetre — the shared scale that keeps figures' real sizes.
  static const double _pxPerCm = 3.5;

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
                      'maks 80/47 poeng. Figurene er tegnet i riktig størrelse '
                      'i forhold til hverandre.',
                    ),
                  ),
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                for (final figure in hold.figures)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        FeltFigureView(
                                          figure: figure,
                                          pxPerCm: _pxPerCm,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          figure.displayName,
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
