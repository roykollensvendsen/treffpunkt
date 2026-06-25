// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Whether Google sign-in will be blocked in the current browser context
/// (spec 0042).
///
/// Google refuses OAuth from an embedded or standalone **webview**
/// ("disallowed_useragent") — e.g. an in-app browser (Messenger, Instagram …)
/// or an iOS "Add to Home Screen" standalone launch. This is a pure check on
/// the [userAgent] and the [isStandalone] display mode so the sign-in screen
/// can warn the user to open the app in Safari/Chrome instead of letting them
/// hit Google's cryptic 403.
///
/// A normal Safari / Chrome / Firefox tab (including iOS Chrome, which carries
/// `CriOS` and is allowed by Google) returns `false`.
bool oauthBlockedHere({required bool isStandalone, String? userAgent}) {
  if (isStandalone) return true;
  final ua = userAgent;
  if (ua == null || ua.isEmpty) return false;
  return _inAppBrowserNeedles.any(ua.contains);
}

/// User-agent fragments that mark a known in-app (embedded) browser where
/// Google OAuth is blocked. Case-sensitive: these tokens are emitted verbatim.
const List<String> _inAppBrowserNeedles = <String>[
  'FBAN', // Facebook app
  'FBAV', // Facebook app version
  'FB_IAB', // Facebook in-app browser
  'Instagram',
  'Line/',
  'Twitter',
  'Snapchat',
  'WhatsApp',
  'MicroMessenger', // WeChat
  'TikTok',
  'BytedanceWebview',
  'Pinterest',
  'LinkedInApp',
  'GSA/', // Google app in-app browser
];
