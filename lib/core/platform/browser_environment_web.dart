// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:js_interop';

import 'package:treffpunkt/core/platform/browser_environment.dart';
import 'package:web/web.dart' as web;

/// iOS-only non-standard flag set when a page runs as a home-screen web app.
@JS('navigator.standalone')
external JSBoolean? get _navigatorStandalone;

/// Reads the real browser context on the web (spec 0042): the user-agent,
/// whether the app is running standalone (installed / "Add to Home Screen"),
/// and the current URL.
BrowserEnvironment readBrowserEnvironment() {
  final byDisplayMode = web.window
      .matchMedia('(display-mode: standalone)')
      .matches;
  final byIosFlag = _navigatorStandalone?.toDart ?? false;
  return BrowserEnvironment(
    userAgent: web.window.navigator.userAgent,
    isStandalone: byDisplayMode || byIosFlag,
    currentUrl: web.window.location.href,
  );
}
