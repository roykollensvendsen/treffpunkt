// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// A [Card]-wrapped [ListTile] announced to a screen reader as one button.
///
/// The [semanticsLabel] and the tap action are carried on the SAME semantics
/// node, so a screen reader can both announce and activate the tile — a
/// labelled "button" with no tap action can be announced but not used. The
/// ListTile's own semantics are excluded to avoid a second, inert node.
///
/// The one navigation tile of the picker pages (spec 0084): category cards,
/// program tiles and the felt-course card all render through here, so the
/// accessibility contract lives in one place.
class TappableCardTile extends StatelessWidget {
  /// Creates the tile.
  const TappableCardTile({
    required this.tileKey,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.onTap,
    super.key,
  });

  /// Key on the inner [ListTile], used by tests to find and tap the tile.
  final Key tileKey;

  /// The tile's title line.
  final String title;

  /// The tile's subtitle line.
  final String subtitle;

  /// What a screen reader announces for the whole tile.
  final String semanticsLabel;

  /// Invoked on tap — by touch and by a screen reader's activate action.
  /// Null renders the tile disabled (muted, no button semantics) — used by
  /// the «kommer senere» MIL category (spec 0097).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Semantics(
        button: onTap != null,
        label: semanticsLabel,
        onTap: onTap,
        child: ExcludeSemantics(
          child: ListTile(
            key: tileKey,
            enabled: onTap != null,
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: onTap == null ? null : const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
