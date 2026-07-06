// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';

/// A participant in a competition (spec 0010): the [userId] that joined, with
/// their [profile] attached for the scoreboard when known.
///
/// A user is a member of a competition at most once (the row is keyed by
/// `(competitionId, userId)`). Membership is created only by the
/// owner-auto-membership trigger or by accepting an invitation.
@immutable
class CompetitionMember {
  /// Creates a membership, optionally carrying the participant's [profile].
  const CompetitionMember({
    required this.competitionId,
    required this.userId,
    this.profile,
    this.joinedAt,
  });

  /// Reads a membership from a `competition_members` row (snake_case columns).
  ///
  /// The [profile] is attached separately by the repository (there is no
  /// foreign key from members to profiles to embed), so it is `null` here.
  factory CompetitionMember.fromJson(Map<String, dynamic> json) {
    return CompetitionMember(
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: parseWireTimeOrNull(json['joined_at'] as String?),
    );
  }

  /// The competition this membership is in.
  final String competitionId;

  /// The auth user id of the participant.
  final String userId;

  /// The participant's profile (name/avatar), or `null` when not loaded.
  final Profile? profile;

  /// When the user joined, or `null` before it is read back.
  final DateTime? joinedAt;

  /// A copy of this membership with [profile] attached.
  CompetitionMember withProfile(Profile? profile) => CompetitionMember(
    competitionId: competitionId,
    userId: userId,
    profile: profile,
    joinedAt: joinedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is CompetitionMember &&
      other.competitionId == competitionId &&
      other.userId == userId &&
      other.profile == profile &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(competitionId, userId, profile, joinedAt);
}
