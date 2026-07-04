// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The blur strength shared by every frosted edge bar (spec 0129).
const double _frostSigma = 14;

/// The translucent surface colour of a frosted bar (specs 0129/0132):
/// clear enough that scrolled content genuinely shows through (the owners
/// found 72 % too milky), while the blur keeps the bar's own labels
/// readable against whatever passes beneath.
Color frostedBarColor(BuildContext context) =>
    Theme.of(context).colorScheme.surface.withValues(alpha: 0.55);

/// Scroll padding for a screen whose content slides under the frosted bars
/// (spec 0129): the content starts below the top bar and above the bottom
/// one, but scrolls beneath them. Use as the scrollable's `padding` together
/// with `extendBodyBehindAppBar`/`extendBody` and a `SafeArea` that leaves
/// top/bottom to the bars.
EdgeInsets frostedScrollPadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double bottom = 16,
}) {
  final inset = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    inset.top + top,
    horizontal,
    inset.bottom + bottom,
  );
}

/// An [AppBar] on frosted glass (spec 0129): translucent and
/// backdrop-blurred, so content scrolling beneath shines through, diffused.
/// Pair with `extendBodyBehindAppBar: true`.
class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar; the parameters pass through to [AppBar].
  const FrostedAppBar({this.title, this.actions, this.leading, super.key});

  /// The bar's title, as [AppBar.title].
  final Widget? title;

  /// Trailing actions, as [AppBar.actions].
  final List<Widget>? actions;

  /// The leading widget, as [AppBar.leading].
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: _frostSigma, sigmaY: _frostSigma),
      child: AppBar(
        backgroundColor: frostedBarColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: title,
        actions: actions,
        leading: leading,
      ),
    ),
  );
}

/// A bottom bar on frosted glass (spec 0129): wraps [child] in the shared
/// blur + translucent surface. Pair with `extendBody: true`.
class FrostedBottomBar extends StatelessWidget {
  /// Creates the bar around [child].
  const FrostedBottomBar({required this.child, super.key});

  /// The bar's content (a [NavigationBar], an action row, …).
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: _frostSigma, sigmaY: _frostSigma),
      child: ColoredBox(color: frostedBarColor(context), child: child),
    ),
  );
}
