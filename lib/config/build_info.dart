// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/presentation/nor_date.dart';

/// The build version injected at deploy time via `--dart-define` (see spec 0028
/// and ADR-0010), so a user can read the running build back to a commit and
/// confirm they are not on a stale page.
///
/// The deploy (`.github/workflows/deploy.yml`) passes `BUILD_SHA` (the same
/// 8-char `${GITHUB_SHA::8}` short SHA spec 0027 stamps into the `?v=`
/// cache-bust query) and `BUILD_TIME` (the UTC build minute). A local or CI
/// build provides neither, so the SHA reads `dev` and the time is empty.
abstract final class BuildInfo {
  /// The deploy's short commit SHA, or `dev` for an unstamped (local/CI) build.
  static const String sha = String.fromEnvironment(
    'BUILD_SHA',
    defaultValue: 'dev',
  );

  /// The deploy's UTC build time (e.g. `2026-06-23T17:30Z`), empty when unset.
  static const String time = String.fromEnvironment('BUILD_TIME');

  /// The human-readable build label, e.g. `build a1b2c3d4 · 2026-06-23T17:30Z`.
  static String get label => formatLabel(sha, time);

  /// Composes the build label from a [sha] and an optional [time].
  ///
  /// The UTC build minute is shown as the phone's local `dd.MM.yyyy HH:mm`
  /// (spec 0118); an unparseable time falls back to the raw string so the
  /// footer never crashes. Pure (it reads no environment values) so it is
  /// unit-testable — the `const` `String.fromEnvironment` values above cannot
  /// be overridden from a test.
  static String formatLabel(String sha, String time) {
    if (time.isEmpty) return 'build $sha';
    final at = DateTime.tryParse(time);
    return 'build $sha · ${at == null ? time : norDateTime(at)}';
  }
}
