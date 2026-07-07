// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/core/presentation/personal_best_banner.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';

/// Key for the scorecard body (specs 0080/0082), for tests.
const Key feltScorecardKey = ValueKey<String>('feltScorecard');

/// A felt round's scorecard (specs 0080/0082/0085): each hold's treff / figur
/// breakdown with its points and ringed-X inner count (the tiebreaker, spec
/// 0085), then the group total. A body widget reused at the end of recording
/// and from the "Mine økter" detail view.
class FeltScorecard extends StatelessWidget {
  /// Creates a scorecard for [session]; [course] defaults to NorgesFelt
  /// 2026 (spec 0145).
  FeltScorecard({
    required this.session,
    FeltCourse? course,
    this.personalBest = false,
    this.holds,
    super.key,
  }) : course = course ?? norgesfelt2026Course;

  /// The scored session to show.
  final FeltSessionTally session;

  /// The course the round was shot on — picks the hold pictures (spec 0145).
  final FeltCourse course;

  /// Whether this round is a new personal best for its group (spec 0101),
  /// celebrated with the «Ny pers!» banner. Only the live finished-round
  /// screen sets it; the historical detail view never celebrates again.
  final bool personalBest;

  /// The round's placed shots per hold (the snapshot's `holds`), or null to
  /// omit the hold pictures. When given, every hold shows its picture with
  /// the shots marked where they landed (spec 0105).
  final List<List<FeltPlacedShot>>? holds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = feltArtForCourse(course);
    return Center(
      key: feltScorecardKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (personalBest)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: PersonalBestBanner(),
              ),
            for (var i = 0; i < session.holds.length; i++) ...[
              ListTile(
                dense: true,
                title: Text('Hold ${i + 1}'),
                subtitle: Text(
                  'Treff ${session.holds[i].treff} · '
                  'Figur ${session.holds[i].figures}',
                ),
                trailing: innerTenScoreText(
                  context: context,
                  lead: '${session.holds[i].points}',
                  innerTens: session.holds[i].inner,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              // The hold picture with the shots where they landed (0105).
              if (holds != null && i < holds!.length && i < art.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FeltHoldShotsView(art: art[i], shots: holds![i]),
                ),
            ],
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _FeltTotalCard(session: session),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round's total in the same filled result card the ring scorecard uses
/// (spec 0089): the group label, the `Poeng · N Ⓧ` line and the big points
/// number on the primary colour.
class _FeltTotalCard extends StatelessWidget {
  const _FeltTotalCard({required this.session});

  final FeltSessionTally session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = scheme.onPrimary;
    return Semantics(
      label:
          'Totalt ${session.group.label}: ${session.points} poeng, '
          '${session.inner} innertreff',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTALT (${session.group.label.toUpperCase()})',
                    style: TextStyle(
                      color: onColor,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  innerTenScoreText(
                    context: context,
                    lead: 'Poeng',
                    innerTens: session.inner,
                    style: TextStyle(color: onColor, fontSize: 18),
                  ),
                ],
              ),
              Text(
                '${session.points}',
                style: TextStyle(
                  color: onColor,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
