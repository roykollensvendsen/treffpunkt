// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/platform/notification_sound.dart';
import 'package:web/web.dart' as web;

/// Plays the bundled shot WAV through an audio element (spec 0134).
class PlatformNotificationSound implements NotificationSound {
  @override
  void play() {
    try {
      // Flutter web serves bundled assets under assets/; the relative URL
      // follows the page's base href, so it works under /treffpunkt/ too.
      web.HTMLAudioElement()
        ..src = 'assets/assets/sounds/jingle.wav'
        ..play();
    } on Object {
      // Best-effort: the browser may refuse audio before the first user
      // interaction — a silent notification beats a crash.
    }
  }
}
