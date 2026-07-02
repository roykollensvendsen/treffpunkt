// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Formats [at] the Norwegian way — `dd.MM.yyyy HH:mm` (spec 0096) — the one
/// date format every meta line and caption uses.
String norDateTime(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)}.${at.year} '
      '${two(at.hour)}:${two(at.minute)}';
}
