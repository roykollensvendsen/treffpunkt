// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/forum/domain/forum_reaction.dart';

/// One reply in a forum thread (spec 0054): who said it ([authorId]), the
/// [body], and when, with [authorName] attached for display when known.
@immutable
class ForumPost {
  /// Creates a reply.
  const ForumPost({
    required this.id,
    required this.threadId,
    required this.body,
    this.authorId,
    this.authorName,
    this.createdAt,
    this.reactions = const <ForumReaction>[],
    this.imagePath,
    this.imageUrl,
  });

  /// Reads a reply from a `forum_posts` row.
  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    return ForumPost(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      authorId: json['author_id'] as String?,
      body: json['body'] as String,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      imagePath: json['image_path'] as String?,
    );
  }

  /// The reply's client-minted id.
  final String id;

  /// The thread it belongs to.
  final String threadId;

  /// The auth user id of the author, or `null` until defaulted server-side.
  final String? authorId;

  /// The reply text.
  final String body;

  /// The author's display name, attached by the repository, or `null`.
  final String? authorName;

  /// When it was posted, or `null` before it is read back.
  final DateTime? createdAt;

  /// The emoji reactions on this reply (spec 0055), attached by the repository.
  final List<ForumReaction> reactions;

  /// The attached image's object path in `forum-images`, or `null` (spec 0056).
  final String? imagePath;

  /// A displayable (signed) URL for [imagePath], attached by the repo, or
  /// `null`. Not persisted.
  final String? imageUrl;

  /// The columns sent on insert; `author_id` and `created_at` default
  /// server-side.
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'thread_id': threadId,
    'body': body,
    if (imagePath != null) 'image_path': imagePath,
  };

  /// A copy with [authorName] attached.
  ForumPost withAuthorName(String? authorName) => ForumPost(
    id: id,
    threadId: threadId,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with [reactions] attached (spec 0055).
  ForumPost withReactions(List<ForumReaction> reactions) => ForumPost(
    id: id,
    threadId: threadId,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with a displayable [imageUrl] attached (spec 0056).
  ForumPost withImageUrl(String? imageUrl) => ForumPost(
    id: id,
    threadId: threadId,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  @override
  bool operator ==(Object other) =>
      other is ForumPost &&
      other.id == id &&
      other.threadId == threadId &&
      other.authorId == authorId &&
      other.body == body &&
      other.authorName == authorName &&
      other.createdAt == createdAt &&
      other.imagePath == imagePath &&
      other.imageUrl == imageUrl &&
      forumReactionsEqual(other.reactions, reactions);

  @override
  int get hashCode => Object.hash(
    id,
    threadId,
    authorId,
    body,
    authorName,
    createdAt,
    imagePath,
    imageUrl,
    Object.hashAll(reactions),
  );
}
