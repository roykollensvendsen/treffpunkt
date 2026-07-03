// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Formats [at] the Norwegian way — `dd.MM.yyyy HH:mm` (spec 0096) — the one
/// date format every meta line and caption uses. Always the phone's local
/// clock (spec 0118), whatever zone the value arrives in.
String norDateTime(DateTime at) {
  final local = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
