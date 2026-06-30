// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Formats a message timestamp compactly for a chat/forum bubble (spec 0065).
///
/// Shown in the viewer's local time: just `HH:mm` when it is today,
/// `dd.MM HH:mm` earlier this year, and `dd.MM.yyyy HH:mm` in an earlier year.
/// [now] is for tests; it defaults to the current time.
String formatMessageTime(DateTime time, {DateTime? now}) {
  final t = time.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final hm = '${_two(t.hour)}:${_two(t.minute)}';
  final sameDay =
      t.year == reference.year &&
      t.month == reference.month &&
      t.day == reference.day;
  if (sameDay) return hm;
  if (t.year == reference.year) {
    return '${_two(t.day)}.${_two(t.month)} $hm';
  }
  return '${_two(t.day)}.${_two(t.month)}.${t.year} $hm';
}

String _two(int value) => value.toString().padLeft(2, '0');
