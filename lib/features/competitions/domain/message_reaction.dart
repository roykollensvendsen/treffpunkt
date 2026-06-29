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

  @override
  bool operator ==(Object other) =>
      other is MessageReaction &&
      other.messageId == messageId &&
      other.userId == userId &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(messageId, userId, emoji);
}
