// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/platform/image_format.dart';

/// Uploads and posts an image, however the caller's backend does that.
/// [format] is the detected content type — its `extension` names the stored
/// object and its `mimeType` tags the upload.
typedef ImageSender =
    Future<void> Function(Uint8List bytes, ImageFormat format);

/// The shared guard-and-send pipeline for an attached image, whether picked
/// or pasted (spec 0062): detects the format from the bytes' magic numbers,
/// refuses anything but JPG/PNG/GIF with the shared message (spec 0075), and
/// otherwise hands the bytes to [send]. A [send] that throws is reported in a
/// snackbar with the caller's [failureMessage].
Future<void> sendImageBytes(
  BuildContext context, {
  required Uint8List bytes,
  required ImageSender send,
  required String failureMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final format = detectImageFormat(bytes);
  if (format == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text(unsupportedImageMessage)),
    );
    return;
  }
  try {
    await send(bytes, format);
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

/// Picks an image and sends it through [sendImageBytes] (spec 0053/0062).
/// [pickBytes] resolves to the picked file's bytes, or null when the user
/// cancelled — then nothing happens.
Future<void> pickAndSendImage(
  BuildContext context, {
  required Future<Uint8List?> Function() pickBytes,
  required ImageSender send,
  required String failureMessage,
}) async {
  final bytes = await pickBytes();
  if (bytes == null || !context.mounted) return;
  await sendImageBytes(
    context,
    bytes: bytes,
    send: send,
    failureMessage: failureMessage,
  );
}
