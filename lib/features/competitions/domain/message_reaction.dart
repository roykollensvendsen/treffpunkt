// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// One emoji reaction on a chat message (spec 0052): which [userId] reacted to
/// message [messageId] with which [emoji].
///
/// A user may react to a message with several distinct emojis (the row is keyed
/// by `(messageId, userId, emoji)`); reacting again with the same emoji removes
/// it (a toggle).
@immutable
class MessageReaction {
  /// Creates a reaction.
  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
    this.userName,
  });

  /// Reads a reaction from a `competition_message_reactions` row.
  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        messageId: json['message_id'] as String,
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
      );

  /// The message this reaction is on.
  final String messageId;

  /// The auth user id of whoever reacted.
  final String userId;

  /// The emoji they reacted with.
  final String emoji;

  /// The reactor's display name, attached by the repository for the "who
  /// reacted" list, or `null` when not loaded (spec 0059). Excluded from
  /// equality (it is display metadata).
  final String? userName;

  /// A copy with [userName] attached.
  MessageReaction withUserName(String? userName) => MessageReaction(
    messageId: messageId,
    userId: userId,
    emoji: emoji,
    userName: userName,
  );

  @override
  bool operator ==(Object other) =>
      other is MessageReaction &&
      other.messageId == messageId &&
      other.userId == userId &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(messageId, userId, emoji);
}
