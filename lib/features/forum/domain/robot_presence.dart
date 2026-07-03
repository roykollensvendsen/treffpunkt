// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// How fresh Robot Hood's heartbeat must be to count as present
/// (spec 0122): the forum watch beats every ~90 s, so five minutes is
/// three missed beats — machine off, session dead or watch crashed.
const Duration robotPresenceFreshness = Duration(minutes: 5);

/// Whether Robot Hood is listening right now (spec 0122): the last
/// heartbeat [seenAt] is within [robotPresenceFreshness] of [now]. A
/// missing heartbeat is simply absent.
bool robotHoodPresent({required DateTime? seenAt, required DateTime now}) =>
    seenAt != null && now.difference(seenAt) <= robotPresenceFreshness;
