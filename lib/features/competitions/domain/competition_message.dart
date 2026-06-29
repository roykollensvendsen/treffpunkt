// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
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
  });

  /// Reads a message from a `competition_messages` row (snake_case columns).
  ///
  /// The [profile] is attached separately by the repository (there is no
  /// foreign key from messages to profiles to embed), so it is `null` here.
  factory CompetitionMessage.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    return CompetitionMessage(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String?,
      body: json['body'] as String,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
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

  /// The columns sent on insert; `user_id` and `created_at` default
  /// server-side (`auth.uid()` / `now()`), so they are omitted.
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'competition_id': competitionId,
    'body': body,
  };

  /// A copy with [profile] attached.
  CompetitionMessage withProfile(Profile? profile) => CompetitionMessage(
    id: id,
    competitionId: competitionId,
    userId: userId,
    body: body,
    createdAt: createdAt,
    profile: profile,
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
  );

  @override
  bool operator ==(Object other) =>
      other is CompetitionMessage &&
      other.id == id &&
      other.competitionId == competitionId &&
      other.userId == userId &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.profile == profile;

  @override
  int get hashCode =>
      Object.hash(id, competitionId, userId, body, createdAt, profile);
}
