// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The shareable join link for a competition (spec 0048): the app's [base] URL
/// with `?join=<competitionId>&token=<token>`, preserving the scheme/host/path
/// and dropping any existing query or fragment.
///
/// Pure — the screen passes `Uri.base` (the deployed web app on the web). The
/// recipient opens this link, signs in if needed, and joins.
Uri competitionJoinLink(
  Uri base, {
  required String competitionId,
  required String token,
}) => base
    .replace(
      queryParameters: <String, String>{
        'join': competitionId,
        'token': token,
      },
    )
    .removeFragment();
