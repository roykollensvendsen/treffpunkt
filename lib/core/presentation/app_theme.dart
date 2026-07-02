// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The seed colour both themes are generated from (spec 0100): a deep
/// blue-graphite — the calm base of a shooting range — with the signal red
/// of a hit reserved for the moments that matter ([TreffColors]).
const Color _seedColor = Color(0xFF1D3557);

/// The app's semantic sport colours (spec 0100), one set per brightness —
/// the domain language of electronic targets (Megalink/SIUS/Kongsberg):
/// the *latest* shot pops in signal red, older shots stay neutral.
@immutable
class TreffColors extends ThemeExtension<TreffColors> {
  /// Creates the colour set.
  const TreffColors({
    required this.lastShot,
    required this.olderShot,
    required this.draggedShot,
    required this.paper,
  });

  /// The newest shot's marker — the app's signal red, also the "hit moment"
  /// accent (a personal best, the inner-ten pulse).
  final Color lastShot;

  /// Markers of earlier shots — neutral, so the newest stays the story.
  final Color olderShot;

  /// A shot while it is being dragged to a corrected position.
  final Color draggedShot;

  /// The target paper. Slightly warm, so a scorecard full of review targets
  /// never turns into a wall of floodlights in dark mode.
  final Color paper;

  /// The light set.
  static const TreffColors light = TreffColors(
    lastShot: Color(0xFFD62828),
    olderShot: Color(0xFF3D7EB8),
    draggedShot: Color(0xFFE9A035),
    paper: Color(0xFFFAF7F0),
  );

  /// The dark set — the same hues stepped for the dark surface.
  static const TreffColors dark = TreffColors(
    lastShot: Color(0xFFE85D5D),
    olderShot: Color(0xFF7FA8C9),
    draggedShot: Color(0xFFE9A035),
    paper: Color(0xFFF4F1EA),
  );

  @override
  TreffColors copyWith({
    Color? lastShot,
    Color? olderShot,
    Color? draggedShot,
    Color? paper,
  }) => TreffColors(
    lastShot: lastShot ?? this.lastShot,
    olderShot: olderShot ?? this.olderShot,
    draggedShot: draggedShot ?? this.draggedShot,
    paper: paper ?? this.paper,
  );

  @override
  TreffColors lerp(TreffColors? other, double t) {
    if (other == null) return this;
    return TreffColors(
      lastShot: Color.lerp(lastShot, other.lastShot, t)!,
      olderShot: Color.lerp(olderShot, other.olderShot, t)!,
      draggedShot: Color.lerp(draggedShot, other.draggedShot, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
    );
  }

  /// The set for [context]'s theme.
  static TreffColors of(BuildContext context) =>
      Theme.of(context).extension<TreffColors>() ?? light;
}

/// The light theme (spec 0030/0100).
final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
  extensions: const [TreffColors.light],
);

/// The dark theme — the same seed at `Brightness.dark`, so the dark palette
/// matches the light one (spec 0030/0100).
final ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
  extensions: const [TreffColors.dark],
);
