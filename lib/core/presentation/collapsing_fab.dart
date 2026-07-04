// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// A floating action button that starts extended (icon + label) and
/// morphs into a round icon-only button while the page is scrolled
/// (specs 0138/0139) — the label re-appears at the top, where there is
/// room and a first-time user needs the words.
///
/// The transition is one continuous animation (spec 0139): the label's
/// width and opacity are driven by a single curve, so the pill glides
/// into a circle instead of swapping widgets.
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 0 : 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) => Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            key: buttonKey,
            elevation: 6,
            shadowColor: Colors.black45,
            color: scheme.primaryContainer,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, color: scheme.onPrimaryContainer),
                    // The label glides away: its width and opacity follow
                    // the same curve, clipped so it never overflows the
                    // shrinking pill.
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        heightFactor: 1,
                        child: Opacity(
                          opacity: t,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
