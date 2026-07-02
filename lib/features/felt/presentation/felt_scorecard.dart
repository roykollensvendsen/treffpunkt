// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

/// Key for the scorecard body (specs 0080/0082), for tests.
const Key feltScorecardKey = ValueKey<String>('feltScorecard');

/// A felt round's scorecard (specs 0080/0082/0085): each hold's treff / figur
/// breakdown with its points and ringed-X inner count (the tiebreaker, spec
/// 0085), then the group total. A body widget reused at the end of recording
/// and from the "Mine økter" detail view.
class FeltScorecard extends StatelessWidget {
  /// Creates a scorecard for [session].
  const FeltScorecard({required this.session, super.key});

  /// The scored session to show.
  final FeltSessionTally session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: feltScorecardKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            for (var i = 0; i < session.holds.length; i++)
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
