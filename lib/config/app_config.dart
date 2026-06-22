// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Compile-time configuration injected via `--dart-define` (see ADR-0010).
///
/// Pass these with, e.g.,
/// `flutter run --dart-define-from-file=config/env.local.json`.
abstract final class AppConfig {
  /// The Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The Supabase publishable (anon) key — safe to ship; data is RLS-guarded.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Whether both required values were provided at build time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
