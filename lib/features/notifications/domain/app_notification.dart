// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// What a notification is about (spec 0094) — decides where tapping it goes.
enum AppNotificationKind {
  /// A competition invitation to me → the competitions hub.
  invitation,

  /// A chat message in one of my competitions → that competition's chat.
  competitionMessage,

  /// A reply in a forum thread I participate in → that thread.
  forumReply,
}

/// One in-app notification (spec 0094): what happened, where it leads and
/// whether it has been read. A pure-Dart value type.
@immutable
class AppNotification {
  /// Creates a notification.
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.competitionId,
    this.threadId,
    this.readAt,
  });

  /// Rebuilds a notification from a Supabase row.
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: switch (json['kind'] as String) {
          'invitation' => AppNotificationKind.invitation,
          'competition_message' => AppNotificationKind.competitionMessage,
          _ => AppNotificationKind.forumReply,
        },
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        competitionId: json['competition_id'] as String?,
        threadId: json['thread_id'] as String?,
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
      );

  /// Stable id.
  final String id;

  /// What happened.
  final AppNotificationKind kind;

  /// The headline shown in the list (and a future OS push).
  final String title;

  /// A short snippet of the message, when there is one.
  final String body;

  /// When the event happened.
  final DateTime createdAt;

  /// The competition it points to, for the competition kinds.
  final String? competitionId;

  /// The forum thread it points to, for [AppNotificationKind.forumReply].
  final String? threadId;

  /// When the recipient read it, or null while unread.
  final DateTime? readAt;

  /// Whether the notification is still unread.
  bool get unread => readAt == null;

  /// A copy marked read at [at].
  AppNotification markRead(DateTime at) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    competitionId: competitionId,
    threadId: threadId,
    readAt: readAt ?? at,
  );
}
