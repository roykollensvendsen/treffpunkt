// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// The kind of shooting a program belongs to.
enum Discipline {
  /// Rifle disciplines (e.g. 10 m air rifle).
  rifle,

  /// Pistol disciplines (e.g. 25 m pistol).
  pistol,
}

/// One stage of a program: a number of series shot on a single target face.
///
/// A stage fixes the [geometry] (the face), how many shots make up one series
/// ([shotsPerSeries]) and how many series the stage has ([seriesCount]).
class StageDefinition {
  /// Creates a stage definition.
  const StageDefinition({
    required this.name,
    required this.geometry,
    required this.shotsPerSeries,
    required this.seriesCount,
    this.secondsPerSeries,
  });

  /// Human-readable stage name, e.g. `'Presisjon'`.
  final String name;

  /// The target face shot in this stage.
  final TargetGeometry geometry;

  /// How many shots make up one series (one target face).
  final int shotsPerSeries;

  /// How many series the stage has.
  final int seriesCount;

  /// Time limit per series in seconds, or `null` for no limit.
  final int? secondsPerSeries;

  /// Total shots in the stage ([shotsPerSeries] × [seriesCount]).
  int get totalShots => shotsPerSeries * seriesCount;
}

/// A seeded definition of an official shooting program (øvelse).
///
/// See `docs/reference/program-catalogue.md`; each catalogue row is one of these.
class ProgramDefinition {
  /// Creates a program definition.
  const ProgramDefinition({
    required this.name,
    required this.discipline,
    required this.stages,
    this.weaponClasses = const <String>[],
  });

  /// Human-readable program name shown to the shooter.
  final String name;

  /// The discipline this program belongs to.
  final Discipline discipline;

  /// The stages shot, in order.
  final List<StageDefinition> stages;

  /// Permitted weapon class / calibre label(s), or empty if unrestricted.
  final List<String> weaponClasses;

  /// Total shots across every stage.
  int get totalShots => stages.fold(0, (sum, stage) => sum + stage.totalShots);
}
