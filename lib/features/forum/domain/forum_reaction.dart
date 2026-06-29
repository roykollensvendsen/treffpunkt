// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// One emoji reaction on a forum thread or reply (spec 0055): which [userId]
/// reacted with which [emoji]. The target (thread/post) is known from where the
/// reaction is attached, so it is not carried here.
@immutable
class ForumReaction {
  /// Creates a reaction.
  const ForumReaction({required this.userId, required this.emoji});

  /// Reads a reaction from a `forum_reactions` row.
  factory ForumReaction.fromJson(Map<String, dynamic> json) => ForumReaction(
    userId: json['user_id'] as String,
    emoji: json['emoji'] as String,
  );

  /// The auth user id of whoever reacted.
  final String userId;

  /// The emoji they reacted with.
  final String emoji;

  @override
  bool operator ==(Object other) =>
      other is ForumReaction && other.userId == userId && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(userId, emoji);
}

/// Order-sensitive equality for two reaction lists — the repository reads them
/// in a stable order, so a reaction added/removed makes the thread or post
/// compare unequal and the view rebuilds (spec 0055).
bool forumReactionsEqual(List<ForumReaction> a, List<ForumReaction> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
