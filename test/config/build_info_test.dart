// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit test for the build-version label (spec 0028). `String.fromEnvironment`
// is a compile-time const and cannot be overridden from a test, so the logic
// lives in the pure `formatLabel`, which is what we exercise here.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/config/build_info.dart';

void main() {
  group('BuildInfo.formatLabel', () {
    test('drops the separator when no build time is given', () {
      expect(BuildInfo.formatLabel('abc1234', ''), 'build abc1234');
    });

    test('joins the sha and time with a middot when a time is given', () {
      expect(
        BuildInfo.formatLabel('abc1234', '2026-06-23T17:30Z'),
        'build abc1234 · 2026-06-23T17:30Z',
      );
    });
  });

  group('BuildInfo defaults (no --dart-define in a test build)', () {
    test('the sha falls back to dev', () {
      expect(BuildInfo.sha, 'dev');
    });

    test('the label is the dev fallback', () {
      expect(BuildInfo.label, 'build dev');
    });
  });
}
