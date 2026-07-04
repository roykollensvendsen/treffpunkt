// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// A floating action button that starts extended (icon + label) and
/// collapses to a round icon-only button while the page is scrolled
/// (spec 0138) — the label re-appears at the top, where there is room
/// and a first-time user needs the words.
class CollapsingFab extends StatelessWidget {
  /// Creates the button.
  const CollapsingFab({
    required this.collapsed,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  /// Whether the button is in its round, icon-only state.
  final bool collapsed;

  /// The action's icon.
  final IconData icon;

  /// The action's label — shown extended, spoken/tooltipped collapsed.
  final String label;

  /// The action.
  final VoidCallback onPressed;

  /// The stable key tests find the button by, in either state.
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    transitionBuilder: (child, animation) =>
        ScaleTransition(scale: animation, child: child),
    child: collapsed
        ? FloatingActionButton(
            key: buttonKey,
            onPressed: onPressed,
            tooltip: label,
            child: Icon(icon),
          )
        : FloatingActionButton.extended(
            key: buttonKey,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
  );
}
