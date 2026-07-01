// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';

/// The scorecard for a saved felt round opened from "Mine økter" (spec 0082).
class FeltSessionDetailScreen extends StatelessWidget {
  /// Creates the detail screen for [record].
  const FeltSessionDetailScreen({required this.record, super.key});

  /// The saved round to show.
  final FeltSessionRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NorgesFelt-løype 2026')),
    body: SafeArea(child: FeltScorecard(session: record.tally)),
  );
}
