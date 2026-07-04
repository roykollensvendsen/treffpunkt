// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/notifications/data/notifications_repository.dart';
import 'package:treffpunkt/features/notifications/domain/app_notification.dart';

/// The Supabase-backed notifications repository (spec 0094). RLS scopes
/// every read and update to the signed-in recipient.
class SupabaseNotificationsRepository implements NotificationsRepository {
  /// Creates the repository over the given Supabase client.
  SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'notifications';

  @override
  Stream<List<AppNotification>> watch() {
    final controller = StreamController<List<AppNotification>>();
    RealtimeChannel? sub;

    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await list());
    }

    controller
      ..onListen = () {
        final uid = _client.auth.currentUser?.id;
        sub = _client
            .channel('notifications:${uid ?? 'anon'}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              filter: uid == null
                  ? null
                  : PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'user_id',
                      value: uid,
                    ),
              callback: (_) => unawaited(emit()),
            )
            .subscribe();
        unawaited(emit());
      }
      ..onCancel = () async {
        final open = sub;
        if (open != null) await _client.removeChannel(open);
        await controller.close();
      };
    return controller.stream;
  }

  @override
  Future<List<AppNotification>> list() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return <AppNotification>[
        for (final row in rows) AppNotification.fromJson(row),
      ];
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to list notifications: $error');
      }
      return const <AppNotification>[];
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _client
          .from(_table)
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to mark the notification read: $error');
      }
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to delete the notification: $error');
      }
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      // RLS scopes the delete to the recipient's own rows; the always-true
      // filter is only there because PostgREST refuses an unfiltered delete.
      await _client.from(_table).delete().gte('created_at', '1970-01-01');
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to delete the notifications: $error');
      }
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _client
          .from(_table)
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .filter('read_at', 'is', null);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to mark the notifications read: $error');
      }
    }
  }
}
