// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// The seeded catalogue of official shooting programs.
///
/// See `docs/reference/program-catalogue.md`. Programs are added as their
/// geometry and structure are confirmed (ISSF first, NSF-specific structures
/// pinned with the source / the father before being locked here).
abstract final class ProgramCatalogue {
  /// The 10 m air-rifle program: a single 10-shot series.
  static const ProgramDefinition airRifle10m = ProgramDefinition(
    name: '10 m Air Rifle',
    discipline: Discipline.rifle,
    weaponClasses: <String>['Air 4.5 mm'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Series',
        geometry: TargetGeometry.airRifle10m(),
        shotsPerSeries: 10,
        seriesCount: 1,
      ),
    ],
  );

  /// All seeded programs, in display order.
  static const List<ProgramDefinition> all = <ProgramDefinition>[airRifle10m];
}
