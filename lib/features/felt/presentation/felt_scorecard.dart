// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

/// Key for the scorecard body (specs 0080/0082), for tests.
const Key feltScorecardKey = ValueKey<String>('feltScorecard');

/// A felt round's scorecard (specs 0080/0082): each hold's treff / figur /
/// inner and points, then the group total. A body widget reused at the end of
/// recording and from the "Mine økter" detail view.
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
                  'Figur ${session.holds[i].figures} · '
                  'Inner ${session.holds[i].inner}',
                ),
                trailing: Text(
                  '${session.holds[i].points}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            const Divider(),
            ListTile(
              title: Text(
                'Totalt (${session.group.label})',
                style: theme.textTheme.titleMedium,
              ),
              trailing: Text(
                '${session.points} poeng',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
