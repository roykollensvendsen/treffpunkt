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

    test('joins the sha and the LOCAL build time with a middot (0118)', () {
      final local = DateTime.utc(2026, 6, 23, 17, 30).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(
        BuildInfo.formatLabel('abc1234', '2026-06-23T17:30Z'),
        'build abc1234 · ${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}',
      );
    });

    test('an unparseable time is shown as-is (never crash the footer)', () {
      expect(
        BuildInfo.formatLabel('abc1234', 'garbage'),
        'build abc1234 · garbage',
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
