// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:treffpunkt/features/notifications/domain/app_notification.dart';

/// The account's notifications (spec 0094): list newest first and mark read.
///
/// Reads are background-tolerant: a failure surfaces as an empty list at the
/// call sites (never an error screen), mirroring the sync repositories.
abstract interface class NotificationsRepository {
  /// The recipient's notifications, newest first.
  Future<List<AppNotification>> list();

  /// The notifications as a live stream (spec 0134): the current list on
  /// listen, then again on every arrival/change — the shot-sound trigger
  /// and the live badge.
  Stream<List<AppNotification>> watch();

  /// Marks the notification [id] read; idempotent.
  Future<void> markRead(String id);

  /// Marks every unread notification read.
  Future<void> markAllRead();

  /// Deletes the notification [id]; idempotent (spec 0109).
  Future<void> delete(String id);

  /// Deletes every notification of the recipient (spec 0109).
  Future<void> deleteAll();
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
  final StreamController<List<AppNotification>> _changes =
      StreamController<List<AppNotification>>.broadcast();

  Future<void> _emit() async => _changes.add(await list());

  @override
  Stream<List<AppNotification>> watch() async* {
    yield await list();
    yield* _changes.stream;
  }

  /// Delivers a new notification, as the backend's fan-out would
  /// (spec 0134) — the test/demo hook for arrivals.
  Future<void> push(AppNotification notification) async {
    _byId[notification.id] = notification;
    await _emit();
  }

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

  @override
  Future<void> delete(String id) async => _byId.remove(id);

  @override
  Future<void> deleteAll() async => _byId.clear();
}
