// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/notification_sound_stub.dart'
    if (dart.library.js_interop) 'package:treffpunkt/core/platform/notification_sound_web.dart'
    as impl;

/// Plays the app's shot sound when a notification arrives (spec 0134).
///
/// The real implementation (web only) plays the bundled WAV through an
/// audio element; off the web — and in tests — the stub is silent. A fake
/// counts plays in tests.
// ignore: one_member_abstracts — a seam with a web impl, a stub and a fake.
abstract interface class NotificationSound {
  /// Fires the shot. Best-effort: playback failures are swallowed (the
  /// browser may block audio before the first user interaction).
  void play();
}

/// The platform's [NotificationSound].
final notificationSoundProvider = Provider<NotificationSound>(
  (ref) => impl.PlatformNotificationSound(),
);
