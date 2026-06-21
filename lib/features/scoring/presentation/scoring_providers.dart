// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

/// The placed shot together with whether the user is currently dragging it.
class ShotPlacement {
  /// Creates a placement. With no [shot], nothing has been placed yet.
  const ShotPlacement({this.shot, this.isDragging = false});

  /// The placed shot, or `null` if none has been placed.
  final Shot? shot;

  /// Whether the placed shot is currently picked up and being dragged.
  final bool isDragging;
}

/// Holds the placed shot and its drag state.
class ShotPlacementNotifier extends Notifier<ShotPlacement> {
  @override
  ShotPlacement build() => const ShotPlacement();

  /// Places (or moves) the shot at [shot] and clears any drag state.
  void place(Shot shot) => state = ShotPlacement(shot: shot);

  /// Picks up the shot at [shot] for dragging (marks it as being moved).
  void pickUp(Shot shot) => state = ShotPlacement(shot: shot, isDragging: true);

  /// Moves the picked-up shot to [shot], keeping it being dragged.
  void dragTo(Shot shot) => state = ShotPlacement(shot: shot, isDragging: true);

  /// Drops the shot at its current position, ending the drag.
  void drop() {
    final shot = state.shot;
    if (shot != null) {
      state = ShotPlacement(shot: shot);
    }
  }
}

/// The current shot placement (the shot and whether it is being dragged).
final shotPlacementProvider =
    NotifierProvider<ShotPlacementNotifier, ShotPlacement>(
      ShotPlacementNotifier.new,
    );
