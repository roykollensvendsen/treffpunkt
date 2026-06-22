// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// A shooting program (øvelse): the discipline name, the target to shoot on,
/// and how many shots make up one series (one target face).
///
/// This is the single-stage form needed to record one series; the full
/// multi-stage program model (ADR-0012) arrives with its consumers.
class Program {
  /// Creates a program named [name] shooting [shotsPerSeries] shots per series
  /// on [geometry].
  const Program({
    required this.name,
    required this.geometry,
    required this.shotsPerSeries,
  });

  /// The 10 m air-rifle program: a 10-shot series on the air-rifle target.
  static const Program airRifle10m = Program(
    name: '10 m Air Rifle',
    geometry: TargetGeometry.airRifle10m(),
    shotsPerSeries: 10,
  );

  /// Human-readable discipline name shown to the shooter.
  final String name;

  /// The target the series is shot on.
  final TargetGeometry geometry;

  /// How many shots make up one series.
  final int shotsPerSeries;

  /// A fresh, empty series for this program.
  Series newSeries() => Series(geometry: geometry, capacity: shotsPerSeries);
}
