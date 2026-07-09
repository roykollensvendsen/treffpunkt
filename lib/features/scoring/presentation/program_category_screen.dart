// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/empty_state.dart';
import 'package:treffpunkt/core/presentation/tappable_card_tile.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_setup_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_category.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart'
    show categoryPictogram;
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

/// Key for the empty-category placeholder (spec 0084 req 4), used by tests.
const Key emptyCategoryKey = ValueKey<String>('category-empty');

/// One category of the program picker (spec 0084): the programs of *NSF Luft*
/// or *NSF Fin/Grov*, the felt courses under *Felt*, or the empty state of a
/// category with nothing seeded yet (*MIL*).
///
/// Holds no session state of its own: the front page re-reads the session
/// store when this page pops (see `ProgramPickerScreen._openCategory`), so a
/// recording started and left mid-session below this page still surfaces as
/// the front page's "Fortsett økt" card.
class ProgramCategoryScreen extends StatelessWidget {
  /// Creates the page for [category].
  const ProgramCategoryScreen({required this.category, super.key});

  /// The category whose content this page lists.
  final ProgramCategory category;

  @override
  Widget build(BuildContext context) {
    return ContentScaffold(
      title: Text(category.label),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (category == ProgramCategory.felt) return _courses(context);
    final programs = ProgramCatalogue.inCategory(category);
    if (programs.isEmpty) {
      return const EmptyState(
        icon: Icons.gps_fixed,
        title: 'Ingen programmer i denne kategorien ennå.',
        titleKey: emptyCategoryKey,
        hint: 'Programmene kommer i en senere versjon.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final definition in programs)
          TappableCardTile(
            tileKey: ValueKey<String>('program-${definition.name}'),
            leading: categoryPictogram(category),
            title: definition.name,
            subtitle: _subtitle(definition),
            semanticsLabel:
                'Velg program: ${definition.name}, '
                '${_subtitle(definition)}',
            onTap: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionSetupScreen(program: definition),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The felt programs (specs 0068/0145/0147): each course as a 6-shot
  /// (Gruppe 1) and a 5-shot (Gruppe 2) variant, straight to the setup —
  /// like the ring categories. «Se løypa» on the setup previews the holds.
  Widget _courses(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final course in feltCourses)
          for (final group in FeltShooterGroup.offered)
            TappableCardTile(
              tileKey: ValueKey<String>('felt-${course.id}-${group.name}'),
              leading: categoryPictogram(ProgramCategory.felt),
              title: course.name,
              subtitle:
                  '${group.shotsPerHold} skudd per hold (${group.label}) · '
                  'maks ${course.maxPoints(group)} poeng',
              semanticsLabel:
                  'Velg program: ${course.name}, '
                  '${group.shotsPerHold} skudd per hold (${group.label}), '
                  'maks ${course.maxPoints(group)} poeng',
              onTap: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FeltSetupScreen(course: course, group: group),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

String _subtitle(ProgramDefinition definition) {
  final discipline = definition.discipline == Discipline.rifle
      ? 'Rifle'
      : 'Pistol';
  return '$discipline · ${definition.totalShots} skudd';
}
