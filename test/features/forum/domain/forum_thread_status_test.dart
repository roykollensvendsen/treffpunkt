// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the thread-status lifecycle values (specs 0066/0117).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';

void main() {
  test('in_progress round-trips through the wire (spec 0117)', () {
    expect(ForumThreadStatus.inProgress.wire, 'in_progress');
    expect(
      ForumThreadStatus.fromWire('in_progress'),
      ForumThreadStatus.inProgress,
    );
    expect(ForumThreadStatus.inProgress.label, 'Jobber med');
  });

  test('an unknown wire value still falls back to open (spec 0066)', () {
    expect(ForumThreadStatus.fromWire('later-added'), ForumThreadStatus.open);
    expect(ForumThreadStatus.fromWire(null), ForumThreadStatus.open);
  });
}
