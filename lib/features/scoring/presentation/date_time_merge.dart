// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Merges a picked calendar [date] and a picked clock time ([hour] / [minute])
/// onto [base].
///
/// This is the pure date/time merge used by the session setup screen: combining
/// the native date and time pickers means taking the calendar date (year /
/// month / day) from one picker and the clock time (hour / minute) from another,
/// leaving the seconds and finer parts of [base] alone. Pass `null` for [date]
/// to keep [base]'s date, and `null` for [hour] / [minute] to keep [base]'s
/// time. The result reuses [base]'s seconds and milliseconds and stays in
/// [base]'s UTC/local mode. Kept Flutter-free so it is unit-testable in
/// isolation.
DateTime mergeDateTime(
  DateTime base, {
  DateTime? date,
  int? hour,
  int? minute,
}) {
  final year = date?.year ?? base.year;
  final month = date?.month ?? base.month;
  final day = date?.day ?? base.day;
  return base.isUtc
      ? DateTime.utc(
          year,
          month,
          day,
          hour ?? base.hour,
          minute ?? base.minute,
          base.second,
          base.millisecond,
          base.microsecond,
        )
      : DateTime(
          year,
          month,
          day,
          hour ?? base.hour,
          minute ?? base.minute,
          base.second,
          base.millisecond,
          base.microsecond,
        );
}
