// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/forum/domain/forum_reaction.dart';

/// What a forum thread is about (spec 0054).
enum ForumCategory {
  /// A bug report.
  bug('bug', 'Bug'),

  /// A feature wish or idea.
  idea('idea', 'Ønske'),

  /// Anything else.
  general('general', 'Generelt');

  const ForumCategory(this.wire, this.label);

  /// The value stored in the database.
  final String wire;

  /// The Norwegian label shown in the app.
  final String label;

  /// The category for a stored [wire] value, defaulting to [general] for an
  /// unknown one (so an added category never crashes an older client).
  static ForumCategory fromWire(String? wire) =>
      ForumCategory.values.firstWhere(
        (c) => c.wire == wire,
        orElse: () => ForumCategory.general,
      );
}

/// One forum thread (spec 0054): a categorised topic with a title and opening
/// body, started by [authorId]. [authorName] is attached for display when set.
@immutable
class ForumThread {
  /// Creates a thread.
  const ForumThread({
    required this.id,
    required this.category,
    required this.title,
    this.body = '',
    this.authorId,
    this.authorName,
    this.createdAt,
    this.reactions = const <ForumReaction>[],
    this.imagePath,
    this.imageUrl,
  });

  /// Reads a thread from a `forum_threads` row.
  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    return ForumThread(
      id: json['id'] as String,
      authorId: json['author_id'] as String?,
      category: ForumCategory.fromWire(json['category'] as String?),
      title: json['title'] as String,
      body: (json['body'] as String?) ?? '',
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      imagePath: json['image_path'] as String?,
    );
  }

  /// The thread's client-minted id.
  final String id;

  /// The auth user id of the starter, or `null` until defaulted server-side.
  final String? authorId;

  /// What the thread is about.
  final ForumCategory category;

  /// The thread title.
  final String title;

  /// The opening message.
  final String body;

  /// The starter's display name, attached by the repository, or `null`.
  final String? authorName;

  /// When it was started, or `null` before it is read back.
  final DateTime? createdAt;

  /// The emoji reactions on this thread (spec 0055), attached by the repo.
  final List<ForumReaction> reactions;

  /// The opening image's object path in `forum-images`, or `null` (spec 0056).
  final String? imagePath;

  /// A displayable (signed) URL for [imagePath], attached by the repo, or
  /// `null`. Not persisted.
  final String? imageUrl;

  /// The columns sent on insert; `author_id` and `created_at` default
  /// server-side (`auth.uid()` / `now()`).
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'category': category.wire,
    'title': title,
    'body': body,
    if (imagePath != null) 'image_path': imagePath,
  };

  /// A copy with [authorName] attached.
  ForumThread withAuthorName(String? authorName) => ForumThread(
    id: id,
    category: category,
    title: title,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with [reactions] attached (spec 0055).
  ForumThread withReactions(List<ForumReaction> reactions) => ForumThread(
    id: id,
    category: category,
    title: title,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with a displayable [imageUrl] attached (spec 0056).
  ForumThread withImageUrl(String? imageUrl) => ForumThread(
    id: id,
    category: category,
    title: title,
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
      other is ForumThread &&
      other.id == id &&
      other.authorId == authorId &&
      other.category == category &&
      other.title == title &&
      other.body == body &&
      other.authorName == authorName &&
      other.createdAt == createdAt &&
      other.imagePath == imagePath &&
      other.imageUrl == imageUrl &&
      forumReactionsEqual(other.reactions, reactions);

  @override
  int get hashCode => Object.hash(
    id,
    authorId,
    category,
    title,
    body,
    authorName,
    createdAt,
    imagePath,
    imageUrl,
    Object.hashAll(reactions),
  );
}
