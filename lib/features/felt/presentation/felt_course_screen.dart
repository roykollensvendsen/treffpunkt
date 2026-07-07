// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/target_icon.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_setup_screen.dart';

/// Key for the "shoot the course" button on the preview (spec 0080), for tests.
const Key feltShootButtonKey = ValueKey<String>('feltShoot');

/// Key for hold [number]'s card in the course preview (spec 0068), for tests.
Key feltHoldCardKey(int number) => ValueKey<String>('feltHold-$number');

/// A preview of a felt course (specs 0068/0079/0145): the holds each drawn as
/// one composed picture matching the official target sheet, with a "Skyt
/// løypa" recorder (spec 0080). Resuming a saved round lives on the front
/// page alone (spec 0116).
class FeltCourseScreen extends ConsumerWidget {
  /// Creates the course preview; defaults to NorgesFelt 2026.
  FeltCourseScreen({FeltCourse? course, super.key})
    : course = course ?? norgesfelt2026Course;

  /// The course previewed (spec 0145).
  final FeltCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(title: Text(course.name)),
      // The Builder gives a context INSIDE the body, where the
      // Scaffold injects the bar insets (spec 0129).
      body: Builder(
        builder: (context) => SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: frostedScrollPadding(context, horizontal: 12, top: 12),
                children: <Widget>[
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${course.holds.length} hold · 10 sek skytetid · '
                        'maks ${course.maxPoints(FeltShooterGroup.one)}/'
                        '${course.maxPoints(FeltShooterGroup.two)} poeng. '
                        'Hvert hold er tegnet som på den offisielle skiva; '
                        'hvert kort sier hvilke figurer som har innertreff.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: feltShootButtonKey,
                    onPressed: () => unawaited(_shoot(context, ref)),
                    icon: const TargetIcon(size: 20),
                    label: const Text('Skyt løypa'),
                  ),
                  const SizedBox(height: 8),
                  for (final hold in course.holds)
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
                            FeltHoldArtView(art: _artFor(course, hold.number)),
                            const SizedBox(height: 8),
                            Text(
                              'Figurer: '
                              '${hold.figures.map((f) => f.name).join(', ')}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _innerCaption(_artFor(course, hold.number), hold),
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
      ),
    );
  }

  Future<void> _shoot(BuildContext context, WidgetRef ref) async {
    // The setup step first (spec 0092): date/time, place and weapon —
    // the same form the ring programs use.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FeltSetupScreen(course: course)),
    );
    ref.invalidate(feltSavedSessionProvider);
  }
}

/// The composed art for [course]'s hold [number] (specs 0079/0145).
FeltHoldArt _artFor(FeltCourse course, int number) =>
    feltArtForCourse(course).firstWhere((a) => a.number == number);

/// The hold's honest inner-treff line (spec 0104), derived from the measured
/// art — not asserted: «Innertreff på alle figurer», or the count with the
/// ring-less figures named (hold 5's big triangle) when the art's scoring
/// figures line up one-to-one with [hold]'s figure list.
String _innerCaption(FeltHoldArt art, FeltHoldDef hold) {
  final inner = art.innerByScoringFigure;
  final withInner = inner.where((has) => has).length;
  if (withInner == inner.length) return 'Innertreff på alle figurer';
  final missing = <String>[
    if (hold.figures.length == inner.length)
      for (var i = 0; i < inner.length; i++)
        if (!inner[i]) hold.figures[i].name ?? 'figur ${i + 1}',
  ];
  final counts = 'Innertreff på $withInner av ${inner.length} figurer';
  return missing.isEmpty ? counts : '$counts (ikke ${missing.join(', ')})';
}
