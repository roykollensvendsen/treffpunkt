// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the embedded-browser detection (spec 0042): in-app browsers
// and iOS standalone launches are flagged (Google blocks OAuth there), while
// normal Safari / Chrome / iOS Chrome tabs are not.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/embedded_browser.dart';

void main() {
  // Real iOS Safari — must NOT be flagged (it works).
  const iosSafari =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 '
      'Safari/604.1';
  // iOS Chrome (CriOS) — allowed by Google.
  const iosChrome =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0 Mobile/15E148 '
      'Safari/604.1';
  const desktopChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0 Safari/537.36';

  test('normal browsers are not blocked', () {
    for (final ua in <String>[iosSafari, iosChrome, desktopChrome]) {
      expect(
        oauthBlockedHere(userAgent: ua, isStandalone: false),
        isFalse,
        reason: ua,
      );
    }
  });

  test('a null or empty user agent is not blocked', () {
    expect(oauthBlockedHere(isStandalone: false), isFalse);
    expect(oauthBlockedHere(userAgent: '', isStandalone: false), isFalse);
  });

  test('an iOS standalone launch is blocked regardless of the UA', () {
    expect(oauthBlockedHere(userAgent: iosSafari, isStandalone: true), isTrue);
    expect(oauthBlockedHere(isStandalone: true), isTrue);
  });

  test('Facebook / Messenger in-app browsers are blocked', () {
    const messenger =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 '
        '[FBAN/MessengerForiOS;FBAV/451.0.0;FBBV/...]';
    expect(oauthBlockedHere(userAgent: messenger, isStandalone: false), isTrue);
  });

  test('Instagram and WeChat in-app browsers are blocked', () {
    const instagram =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
        'AppleWebKit/605.1.15 Mobile/15E148 Instagram 333.0.0';
    const wechat =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 MicroMessenger/8.0';
    expect(oauthBlockedHere(userAgent: instagram, isStandalone: false), isTrue);
    expect(oauthBlockedHere(userAgent: wechat, isStandalone: false), isTrue);
  });
}
