// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the notification value type (specs 0094/0120).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/notifications/domain/app_notification.dart';

void main() {
  test('reads the mention kind (spec 0120)', () {
    final notification = AppNotification.fromJson(const <String, dynamic>{
      'id': 'n1',
      'kind': 'mention',
      'title': 'Kari nevnte deg: Skiver',
      'body': 'Hei @[Roy]!',
      'created_at': '2026-07-03T10:00:00Z',
      'thread_id': 't1',
    });
    expect(notification.kind, AppNotificationKind.mention);
    expect(notification.threadId, 't1');
  });

  test('an unknown kind still lands on a safe default (spec 0094)', () {
    final notification = AppNotification.fromJson(const <String, dynamic>{
      'id': 'n2',
      'kind': 'somekind-from-the-future',
      'title': 'T',
      'created_at': '2026-07-03T10:00:00Z',
    });
    expect(notification.kind, AppNotificationKind.forumReply);
  });
}
