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
