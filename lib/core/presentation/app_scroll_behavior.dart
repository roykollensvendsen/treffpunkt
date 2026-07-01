// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the **mouse and trackpad** drag scrollables, not just touch — needed on
/// desktop/web (spec 0074).
///
/// Flutter's default omits the mouse from a scrollable's drag devices, so on
/// desktop/web a horizontal strip (e.g. the field-course figures) cannot be
/// swiped — the wheel only scrolls vertically and there is no touch. Adding the
/// mouse and trackpad makes click-and-drag scroll such strips everywhere.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// Creates the app-wide scroll behaviour.
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
