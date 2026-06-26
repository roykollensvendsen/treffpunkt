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

/// A pending "join this competition" request parsed from a deep link.
typedef JoinIntent = ({String competitionId, String token});

/// The [JoinIntent] in [uri]'s `?join=<id>&token=<t>` query, or `null` when
/// either is missing (spec 0048). Pure — the app passes `Uri.base` at startup.
JoinIntent? parseJoinIntent(Uri uri) {
  final competitionId = uri.queryParameters['join'];
  final token = uri.queryParameters['token'];
  if (competitionId == null ||
      competitionId.isEmpty ||
      token == null ||
      token.isEmpty) {
    return null;
  }
  return (competitionId: competitionId, token: token);
}
