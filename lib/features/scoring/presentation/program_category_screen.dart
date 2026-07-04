// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/empty_state.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/core/presentation/tappable_card_tile.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_category.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
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
    return Scaffold(
      appBar: FrostedAppBar(title: Text(category.label)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: _body(context),
          ),
        ),
      ),
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

  /// The felt courses (spec 0068) — today the single NorgesFelt-løype 2026.
  Widget _courses(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TappableCardTile(
          tileKey: const ValueKey<String>('felt-norgesfelt-2026'),
          title: 'NorgesFelt-løype 2026',
          subtitle: 'Forhåndsvis de 8 holdene og figurene',
          semanticsLabel:
              'Velg løype: NorgesFelt-løype 2026, '
              'Forhåndsvis de 8 holdene og figurene',
          onTap: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FeltCourseScreen()),
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
