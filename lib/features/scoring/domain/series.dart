// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// A series: the shots fired on one target face before patching.
///
/// A series holds up to [capacity] shots placed against [geometry]. It is a
/// pure value type — placing or moving a shot returns a new `Series`.
class Series {
  /// Creates a series for [geometry] holding at most [capacity] shots.
  ///
  /// The [shots] are defensively copied into an unmodifiable list, so a series
  /// can only change through [placeShot] / [moveShot].
  Series({
    required this.geometry,
    required this.capacity,
    List<Shot> shots = const <Shot>[],
  }) : shots = List<Shot>.unmodifiable(shots);

  /// The target the shots are scored against.
  final TargetGeometry geometry;

  /// How many shots make up the series (one target face).
  final int capacity;

  /// The shots placed so far, in firing order (length `<=` [capacity]).
  ///
  /// Unmodifiable; use [placeShot] / [moveShot] to change the series.
  final List<Shot> shots;

  /// How many shots have been placed.
  int get placedCount => shots.length;

  /// How many shots remain before the series is full.
  int get remaining => capacity - shots.length;

  /// Whether every shot of the series has been placed.
  bool get isComplete => shots.length >= capacity;

  /// Returns a new series with [shot] appended as the next shot.
  ///
  /// Throws a [StateError] if the series is already full.
  Series placeShot(Shot shot) {
    if (isComplete) {
      throw StateError('series is full ($capacity shots)');
    }
    return _copyWith(shots: <Shot>[...shots, shot]);
  }

  /// Returns a new series with the newest shot removed (spec 0098's Angre).
  ///
  /// Throws a [StateError] if the series has no shots.
  Series removeLastShot() {
    if (shots.isEmpty) {
      throw StateError('series has no shots');
    }
    return _copyWith(shots: shots.sublist(0, shots.length - 1));
  }

  /// Returns a new series with the shot at [index] replaced by [shot].
  ///
  /// Used when a placed shot is moved. Throws a [RangeError] if [index] is not
  /// a placed shot.
  Series moveShot(int index, Shot shot) {
    RangeError.checkValidIndex(index, shots, 'index', shots.length);
    return _copyWith(shots: <Shot>[...shots]..[index] = shot);
  }

  Series _copyWith({List<Shot>? shots}) => Series(
    geometry: geometry,
    capacity: capacity,
    shots: shots ?? this.shots,
  );
}
