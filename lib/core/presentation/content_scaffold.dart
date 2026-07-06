// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/layout.dart';

/// The shared skeleton of a content screen: a [FrostedAppBar] over a
/// [SafeArea] whose body is centered and capped at [kMaxContentWidth], so a
/// list or form reads comfortably on a wide desktop window too.
///
/// Two variants:
///
/// * The default keeps the body below the bar — the everyday page.
/// * [ContentScaffold.behindBar] slides the body under the frosted bar
///   (spec 0129): the scaffold extends the body behind the app bar and the
///   [SafeArea] leaves top and bottom open, so a scrollable body can take
///   `frostedScrollPadding` from its **own** `BuildContext` and start below
///   the glass while scrolling beneath it. (The originals used a `Builder`
///   for this; here [body] is its own widget, so its context already sits
///   inside the scaffold's inset-injecting subtree.)
class ContentScaffold extends StatelessWidget {
  /// Creates the default skeleton: the body starts below the bar.
  const ContentScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    super.key,
  }) : _behindBar = false;

  /// Creates the spec-0129 variant: the body extends behind the frosted bar
  /// and keeps the bar's height as `MediaQuery` padding, for scrollables
  /// padded with `frostedScrollPadding`.
  const ContentScaffold.behindBar({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    super.key,
  }) : _behindBar = true;

  /// The bar's title, as [FrostedAppBar.title].
  final Widget title;

  /// Trailing bar actions, as [FrostedAppBar.actions].
  final List<Widget>? actions;

  /// The screen's content, centered and capped at [kMaxContentWidth].
  final Widget body;

  /// An optional floating action button, as [Scaffold.floatingActionButton].
  final Widget? floatingActionButton;

  final bool _behindBar;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: body,
      ),
    );
    return Scaffold(
      extendBodyBehindAppBar: _behindBar,
      appBar: FrostedAppBar(title: title, actions: actions),
      body: _behindBar
          // Top and bottom stay with the body's scrollable (spec 0129): it
          // pads itself past the bars with `frostedScrollPadding` and lets
          // its content slide beneath them.
          ? SafeArea(top: false, bottom: false, child: content)
          : SafeArea(child: content),
      floatingActionButton: floatingActionButton,
    );
  }
}
