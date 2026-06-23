// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';

/// A shooter's public profile — their display name and avatar — so a shared
/// scoreboard can show who is who without exposing `auth.users` (spec 0010).
///
/// One row per user, keyed by the auth user id. Holds only the already-public
/// Google display name / avatar; the app upserts its own profile on sign-in.
@immutable
class Profile {
  /// Creates a profile for the user [id].
  const Profile({required this.id, this.displayName, this.avatarUrl});

  /// Builds the profile to persist for a signed-in [user].
  factory Profile.fromAppUser(AppUser user) => Profile(
    id: user.id,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
  );

  /// Reads a profile from a `profiles` row (snake_case columns).
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  /// The auth user id this profile belongs to.
  final String id;

  /// The user's display name, if known.
  final String? displayName;

  /// URL of the user's avatar image, if known.
  final String? avatarUrl;

  /// The `profiles` row to upsert (snake_case columns).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'display_name': displayName,
    'avatar_url': avatarUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl);
}
