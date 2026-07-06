// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Parses a wire timestamp into the phone's local zone (spec 0118).
///
/// Every timestamp entering the app — Supabase rows, JSON payloads,
/// backups — goes through here, so every `DateTime` the app holds is
/// local by construction and any formatter shows the phone's clock.
/// A UTC or offset-carrying string is converted to the same instant in
/// local time; an offset-less (already local) string is unchanged, so
/// on-device data reads exactly as it was written.
DateTime parseWireTime(String iso) => DateTime.parse(iso).toLocal();

/// Parses an optional wire timestamp: a missing (`null`) value stays `null`,
/// a present one goes through [parseWireTime].
///
/// The one-liner for the recurring record-decoding move
/// `json['x'] as String?` → `null` or a local [DateTime].
DateTime? parseWireTimeOrNull(String? iso) =>
    iso == null ? null : parseWireTime(iso);

/// Formats an optional instant for the wire as a UTC ISO-8601 string; `null`
/// stays `null`.
///
/// The write-side counterpart of [parseWireTime] for rows leaving the app
/// (Supabase columns): the instant is normalised to UTC so the server stores
/// one unambiguous moment regardless of the phone's zone. On-device JSON
/// (queues, backups) intentionally does **not** use this — it stays in local
/// wall-clock form (spec 0118), written with `toIso8601String()` directly.
String? formatWireTimeUtc(DateTime? time) => time?.toUtc().toIso8601String();
