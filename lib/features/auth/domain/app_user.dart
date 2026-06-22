// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// A signed-in user, as the app understands it (independent of the backend).
class AppUser {
  /// Creates an app user.
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  /// Stable unique identifier for the user.
  final String id;

  /// The user's email address, if known.
  final String? email;

  /// The user's display name, if known.
  final String? displayName;

  /// URL of the user's avatar image, if known.
  final String? avatarUrl;
}
