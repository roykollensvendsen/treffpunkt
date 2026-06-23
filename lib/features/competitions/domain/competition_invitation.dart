// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';

/// An invitation to a competition (spec 0010): the owner invites a person by
/// [invitedEmail]; the invitee accepts to become a member.
///
/// Keyed by `(competitionId, invitedEmail)` (email stored lower-cased). When
/// listed for the invitee, the [competition] it refers to is attached so the
/// screen can show its name and program.
@immutable
class CompetitionInvitation {
  /// Creates an invitation.
  const CompetitionInvitation({
    required this.competitionId,
    required this.invitedEmail,
    this.invitedBy,
    this.status = 'pending',
    this.createdAt,
    this.competition,
  });

  /// Reads an invitation from a `competition_invitations` row (snake_case).
  ///
  /// If the query embedded the competition (`competitions(*)`), it is parsed
  /// into [competition].
  factory CompetitionInvitation.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    final embedded = json['competitions'];
    return CompetitionInvitation(
      competitionId: json['competition_id'] as String,
      invitedEmail: json['invited_email'] as String,
      invitedBy: json['invited_by'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      competition: embedded is Map<String, dynamic>
          ? Competition.fromJson(embedded)
          : null,
    );
  }

  /// The competition the invitation is for.
  final String competitionId;

  /// The invited person's email (lower-cased).
  final String invitedEmail;

  /// The auth user id of the inviter, or `null` when not loaded.
  final String? invitedBy;

  /// `pending` until accepted (then `accepted`).
  final String status;

  /// When the invitation was created, or `null` before it is read back.
  final DateTime? createdAt;

  /// The competition referred to, attached when listed for the invitee.
  final Competition? competition;

  /// The columns a client sets when creating an invitation (the inviter's id
  /// defaults to `auth.uid()` in the database, so it is not sent).
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'competition_id': competitionId,
    'invited_email': invitedEmail.toLowerCase(),
  };

  @override
  bool operator ==(Object other) =>
      other is CompetitionInvitation &&
      other.competitionId == competitionId &&
      other.invitedEmail == invitedEmail &&
      other.invitedBy == invitedBy &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.competition == competition;

  @override
  int get hashCode => Object.hash(
    competitionId,
    invitedEmail,
    invitedBy,
    status,
    createdAt,
    competition,
  );
}
