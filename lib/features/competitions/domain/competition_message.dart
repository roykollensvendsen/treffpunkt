// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/competitions/domain/message_reaction.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

/// One chat message in a competition (spec 0051): who said it ([userId]), the
/// [body], and when ([createdAt]), with the author's [profile] attached for
/// display when known.
///
/// The [id] is client-minted (a uuid), so posting is a plain insert. A message
/// is immutable once posted.
@immutable
class CompetitionMessage {
  /// Creates a message, optionally carrying the author's [profile].
  const CompetitionMessage({
    required this.id,
    required this.competitionId,
    required this.body,
    this.userId,
    this.createdAt,
    this.profile,
    this.reactions = const <MessageReaction>[],
    this.imagePath,
    this.imageUrl,
  });

  /// Reads a message from a `competition_messages` row (snake_case columns).
  ///
  /// The [profile] is attached separately by the repository (there is no
  /// foreign key from messages to profiles to embed), so it is `null` here.
  factory CompetitionMessage.fromJson(Map<String, dynamic> json) {
    return CompetitionMessage(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String?,
      body: json['body'] as String,
      createdAt: parseWireTimeOrNull(json['created_at'] as String?),
      imagePath: json['image_path'] as String?,
    );
  }

  /// The message's client-minted id.
  final String id;

  /// The competition this message belongs to.
  final String competitionId;

  /// The auth user id of the author, or `null` until defaulted server-side.
  final String? userId;

  /// The message text.
  final String body;

  /// When the message was posted, or `null` before it is read back.
  final DateTime? createdAt;

  /// The author's profile (name/avatar), or `null` when not loaded.
  final Profile? profile;

  /// The emoji reactions on this message (spec 0052); empty when none or not
  /// loaded. Attached by the repository alongside the message.
  final List<MessageReaction> reactions;

  /// The attached image's object path in the `chat-images` bucket, or `null`
  /// when the message has no image (spec 0053).
  final String? imagePath;

  /// A displayable (signed) URL for [imagePath], attached by the repository, or
  /// `null` when there is no image. Not persisted.
  final String? imageUrl;

  /// The columns sent on insert; `user_id` and `created_at` default
  /// server-side (`auth.uid()` / `now()`), so they are omitted. `image_path` is
  /// only sent when the message carries an image (spec 0053).
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'competition_id': competitionId,
    'body': body,
    if (imagePath != null) 'image_path': imagePath,
  };

  /// A copy with [profile] attached.
  CompetitionMessage withProfile(Profile? profile) => CompetitionMessage(
    id: id,
    competitionId: competitionId,
    userId: userId,
    body: body,
    createdAt: createdAt,
    profile: profile,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with [userId] set (used by the in-memory fake to default the
  /// author to the acting user, as the database does).
  CompetitionMessage withUser(String? userId) => CompetitionMessage(
    id: id,
    competitionId: competitionId,
    userId: userId,
    body: body,
    createdAt: createdAt,
    profile: profile,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  /// A copy with [reactions] attached (spec 0052).
  CompetitionMessage withReactions(List<MessageReaction> reactions) =>
      CompetitionMessage(
        id: id,
        competitionId: competitionId,
        userId: userId,
        body: body,
        createdAt: createdAt,
        profile: profile,
        reactions: reactions,
        imagePath: imagePath,
        imageUrl: imageUrl,
      );

  /// A copy with a displayable [imageUrl] attached (spec 0053).
  CompetitionMessage withImageUrl(String? imageUrl) => CompetitionMessage(
    id: id,
    competitionId: competitionId,
    userId: userId,
    body: body,
    createdAt: createdAt,
    profile: profile,
    reactions: reactions,
    imagePath: imagePath,
    imageUrl: imageUrl,
  );

  @override
  bool operator ==(Object other) =>
      other is CompetitionMessage &&
      other.id == id &&
      other.competitionId == competitionId &&
      other.userId == userId &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.profile == profile &&
      other.imagePath == imagePath &&
      other.imageUrl == imageUrl &&
      _reactionsEqual(other.reactions, reactions);

  @override
  int get hashCode => Object.hash(
    id,
    competitionId,
    userId,
    body,
    createdAt,
    profile,
    imagePath,
    imageUrl,
    Object.hashAll(reactions),
  );
}

/// Order-sensitive equality for two reaction lists — the repository always
/// reads them in a stable order, so a reaction added or removed makes the
/// message compare unequal and the chat rebuilds (spec 0052).
bool _reactionsEqual(List<MessageReaction> a, List<MessageReaction> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
