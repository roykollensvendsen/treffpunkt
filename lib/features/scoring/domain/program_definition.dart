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
    this.targetsPerSeries = 1,
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

  /// How many separate targets a series is fired across (spec 0067).
  ///
  /// `1` (the default) is the normal case: every shot of the series lands on
  /// the one [geometry]. For a silhouette bank it is `5` — the shooter fires
  /// one shot at each of five identical [geometry] faces, in firing order. The
  /// shots are still stored in order on the single [geometry]; this only drives
  /// how the recording and review screens lay them out (shot _k_ → target
  /// [targetIndexForShot]).
  final int targetsPerSeries;

  /// Total shots in the stage ([shotsPerSeries] × [seriesCount]).
  int get totalShots => shotsPerSeries * seriesCount;

  /// How many shots are fired at each target ([shotsPerSeries] ÷
  /// [targetsPerSeries]); `1` for a one-shot-per-target silhouette bank.
  int get shotsPerTarget => shotsPerSeries ~/ targetsPerSeries;

  /// Which target (0-based) the shot at firing-order index [shotIndex] belongs
  /// to (spec 0067).
  int targetIndexForShot(int shotIndex) => shotIndex ~/ shotsPerTarget;
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
