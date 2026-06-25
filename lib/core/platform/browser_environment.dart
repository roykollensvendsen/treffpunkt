// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/platform/browser_environment_stub.dart'
    if (dart.library.js_interop) 'package:treffpunkt/core/platform/browser_environment_web.dart'
    as impl;

/// The web browser context the app is running in (spec 0042).
///
/// Used to detect contexts where Google sign-in is blocked (an in-app or
/// standalone webview). Off the web — and in tests — it is the empty default.
class BrowserEnvironment {
  /// Creates an environment.
  const BrowserEnvironment({
    this.userAgent,
    this.isStandalone = false,
    this.currentUrl,
  });

  /// The empty environment (non-web platforms and tests).
  const BrowserEnvironment.empty() : this();

  /// The browser's user-agent string, or `null` when not on the web.
  final String? userAgent;

  /// Whether the app is running as an installed/standalone web app (no browser
  /// chrome) — e.g. iOS "Add to Home Screen".
  final bool isStandalone;

  /// The current page URL (for a "copy link" affordance), or `null`.
  final String? currentUrl;
}

/// Reads the real [BrowserEnvironment] on the web; the empty default elsewhere.
BrowserEnvironment readBrowserEnvironment() => impl.readBrowserEnvironment();
