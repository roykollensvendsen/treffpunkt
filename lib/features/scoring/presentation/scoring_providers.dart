// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

/// Holds the single shot the user has placed on the target (`null` = none yet).
class PlacedShotNotifier extends Notifier<Shot?> {
  @override
  Shot? build() => null;

  /// The placed shot, or `null` if none has been placed.
  Shot? get shot => state;

  /// Sets the placed shot; pass `null` to clear it.
  set shot(Shot? value) => state = value;
}

/// The shot currently placed on the target, or `null` if none.
final placedShotProvider = NotifierProvider<PlacedShotNotifier, Shot?>(
  PlacedShotNotifier.new,
);
