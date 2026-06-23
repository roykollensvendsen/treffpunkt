// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The seed colour both themes are generated from, so the light and dark
/// palettes stay in the same family (spec 0030).
const Color _seedColor = Colors.teal;

/// The light theme — the app's original look (a teal-seeded `ColorScheme`).
final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
);

/// The dark theme — the same teal seed at `Brightness.dark`, so the dark
/// palette matches the light one (spec 0030).
final ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
);
