// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the Robot Hood presence rule (spec 0122).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/forum/domain/robot_presence.dart';

void main() {
  final now = DateTime(2026, 7, 3, 14);

  test('a fresh heartbeat is present (spec 0122)', () {
    expect(
      robotHoodPresent(
        seenAt: now.subtract(const Duration(minutes: 2)),
        now: now,
      ),
      isTrue,
    );
  });

  test('a stale heartbeat is absent', () {
    expect(
      robotHoodPresent(
        seenAt: now.subtract(const Duration(minutes: 6)),
        now: now,
      ),
      isFalse,
    );
  });

  test('exactly five minutes still counts as present', () {
    expect(
      robotHoodPresent(
        seenAt: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isTrue,
    );
  });

  test('no heartbeat at all is absent, never an error', () {
    expect(robotHoodPresent(seenAt: null, now: now), isFalse);
  });
}
