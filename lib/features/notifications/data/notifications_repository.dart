// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/notifications/domain/app_notification.dart';

/// The account's notifications (spec 0094): list newest first and mark read.
///
/// Reads are background-tolerant: a failure surfaces as an empty list at the
/// call sites (never an error screen), mirroring the sync repositories.
abstract interface class NotificationsRepository {
  /// The recipient's notifications, newest first.
  Future<List<AppNotification>> list();

  /// Marks the notification [id] read; idempotent.
  Future<void> markRead(String id);

  /// Marks every unread notification read.
  Future<void> markAllRead();
}

/// In-memory fake — the default binding and the test double.
class InMemoryNotificationsRepository implements NotificationsRepository {
  /// Creates the fake, optionally [seeded].
  InMemoryNotificationsRepository({
    List<AppNotification> seeded = const <AppNotification>[],
  }) : _byId = <String, AppNotification>{
         for (final notification in seeded) notification.id: notification,
       };

  final Map<String, AppNotification> _byId;

  @override
  Future<List<AppNotification>> list() async {
    final all = _byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(all);
  }

  @override
  Future<void> markRead(String id) async {
    final found = _byId[id];
    if (found != null) _byId[id] = found.markRead(DateTime.now());
  }

  @override
  Future<void> markAllRead() async {
    final now = DateTime.now();
    for (final entry in _byId.entries.toList()) {
      _byId[entry.key] = entry.value.markRead(now);
    }
  }
}
