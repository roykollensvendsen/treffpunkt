// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

/// Key for the setup screen's «Se løypa» preview action (spec 0147).
const Key feltPreviewCourseKey = ValueKey<String>('feltPreviewCourse');

/// The setup step before a NorgesFelt round (spec 0092): the same shared form
/// the ring programs use — date/time, place and weapon — wrapped with the
/// course title; confirming opens the recorder with the metadata attached.
/// The chosen program is a course + group variant (spec 0147), so the
/// recorder never asks for a group; «Se løypa» previews the holds on demand.
///
/// Every pistol weapon is offered (no class restriction): the course groups
/// imply the weapon type.
class FeltSetupScreen extends StatelessWidget {
  /// Creates the felt setup screen, seeding the date/time from [now]
  /// (defaults to the wall clock; injected in tests).
  FeltSetupScreen({
    required this.group,
    DateTime? now,
    FeltCourse? course,
    this.competitionId,
    super.key,
  }) : now = now ?? DateTime.now(),
       course = course ?? norgesfelt2026Course;

  /// The moment used to seed the editable date and time.
  final DateTime now;

  /// The course the round is shot on (spec 0145).
  final FeltCourse course;

  /// The round's group — the chosen program variant (spec 0147), or the
  /// competition's locked group (spec 0140).
  final FeltShooterGroup group;

  /// The competition this round is shot for (spec 0140), or `null`.
  final String? competitionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostedAppBar(
        title: Text('${course.name} · ${group.label}'),
        actions: [
          // The course preview left the shooting flow (spec 0147); it
          // stays one tap away for studying the holds.
          IconButton(
            key: feltPreviewCourseKey,
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Se løypa',
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FeltCourseScreen(course: course),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SessionSetupForm(
        now: now,
        discipline: Discipline.pistol,
        // Felt has no decimal mode; the toggle is not offered (spec 0107).
        onConfirm: (metadata, weapon, {required decimalEntry}) => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FeltRecordScreen(
                course: course,
                group: group,
                metadata: metadata,
                weapon: weapon,
                competitionId: competitionId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
