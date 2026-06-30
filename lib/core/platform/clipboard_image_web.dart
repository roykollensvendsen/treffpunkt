// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:js_interop';

import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:web/web.dart' as web;

/// Watches the document's `paste` event for image data (spec 0062).
ClipboardImageWatcher createClipboardImageWatcher() =>
    _WebClipboardImageWatcher();

class _WebClipboardImageWatcher implements ClipboardImageWatcher {
  _WebClipboardImageWatcher() {
    _controller = StreamController<PastedImage>.broadcast(
      onListen: _attach,
      onCancel: _detach,
    );
  }

  late final StreamController<PastedImage> _controller;
  JSFunction? _listener;

  @override
  Stream<PastedImage> get images => _controller.stream;

  void _attach() {
    if (_listener != null) return;
    final listener = (web.Event event) {
      final data = (event as web.ClipboardEvent).clipboardData;
      if (data == null) return;
      final files = data.files;
      for (var i = 0; i < files.length; i++) {
        final file = files.item(i);
        if (file != null && file.type.startsWith('image/')) {
          unawaited(_emit(file));
        }
      }
    }.toJS;
    _listener = listener;
    // Capture phase, so a focused text field cannot swallow the event first.
    web.document.addEventListener('paste', listener, true.toJS);
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) {
      web.document.removeEventListener('paste', listener, true.toJS);
      _listener = null;
    }
  }

  Future<void> _emit(web.File file) async {
    final buffer = await file.arrayBuffer().toDart;
    if (_controller.isClosed) return;
    _controller.add(
      PastedImage(
        bytes: buffer.toDart.asUint8List(),
        isPng: file.type == 'image/png',
      ),
    );
  }
}
