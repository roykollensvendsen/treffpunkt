// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/nor_date.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

/// The scorecard for a saved felt round opened from "Mine økter" (spec 0082),
/// captioned with the round's date, group, place and weapon (spec 0092).
class FeltSessionDetailScreen extends StatelessWidget {
  /// Creates the detail screen for [record].
  const FeltSessionDetailScreen({required this.record, super.key});

  /// The saved round to show.
  final FeltSessionRecord record;

  /// The "date · group[ · place][ · weapon]" caption (spec 0092).
  String get _metaLine {
    final date = norDateTime(record.capturedAt);
    final place = record.session.placeLabel;
    return [
      date,
      record.session.group.label,
      if (place != null && place.isNotEmpty) place,
      ?record.session.weaponName,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NorgesFelt-løype 2026')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _metaLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: FeltScorecard(session: record.tally)),
          ],
        ),
      ),
    );
  }
}
