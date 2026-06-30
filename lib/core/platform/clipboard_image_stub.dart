// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/platform/clipboard_image.dart';

/// Off-web (and test) watcher: pasting images is a web-only capability, so this
/// emits nothing (spec 0062).
ClipboardImageWatcher createClipboardImageWatcher() => const _NoClipboard();

class _NoClipboard implements ClipboardImageWatcher {
  const _NoClipboard();

  @override
  Stream<PastedImage> get images => const Stream<PastedImage>.empty();
}
