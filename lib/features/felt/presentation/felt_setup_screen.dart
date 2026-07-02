// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

/// The setup step before a NorgesFelt round (spec 0092): the same shared form
/// the ring programs use — date/time, place and weapon — wrapped with the
/// course title; confirming opens the recorder with the metadata attached.
///
/// Every pistol weapon is offered (no class restriction): the course groups
/// imply the weapon type.
class FeltSetupScreen extends StatelessWidget {
  /// Creates the felt setup screen, seeding the date/time from [now]
  /// (defaults to the wall clock; injected in tests).
  FeltSetupScreen({DateTime? now, super.key}) : now = now ?? DateTime.now();

  /// The moment used to seed the editable date and time.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NorgesFelt-løype 2026')),
      body: SessionSetupForm(
        now: now,
        discipline: Discipline.pistol,
        // Felt has no decimal mode; the toggle is not offered (spec 0107).
        onConfirm: (metadata, weapon, {required decimalEntry}) => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  FeltRecordScreen(metadata: metadata, weapon: weapon),
            ),
          ),
        ),
      ),
    );
  }
}
