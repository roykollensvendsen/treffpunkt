// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/platform/notification_sound.dart';

/// The silent off-web [NotificationSound] (spec 0134).
class PlatformNotificationSound implements NotificationSound {
  @override
  void play() {
    // No audio backend off the web (yet) — silently do nothing.
  }
}
