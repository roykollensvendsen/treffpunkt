// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Shared test fakes: one canonical implementation of each platform/backend
// fake instead of a private copy in every test file.
import 'dart:async';
import 'dart:typed_data';

import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// A clipboard watcher whose paste stream the test drives.
class FakeClipboardImageWatcher implements ClipboardImageWatcher {
  final StreamController<PastedImage> _controller =
      StreamController<PastedImage>.broadcast();

  @override
  Stream<PastedImage> get images => _controller.stream;

  /// Delivers [image] as if the user pasted it.
  void emit(PastedImage image) => _controller.add(image);

  /// Closes the paste stream.
  void dispose() => unawaited(_controller.close());
}

/// A [Sharer] that records what was shared instead of opening the real OS
/// share sheet — both plain [share] texts and the last [shareFile] payload.
class RecordingSharer implements Sharer {
  /// Every text passed to [share], in order.
  final List<String> shared = <String>[];

  /// The filename of the last [shareFile] call, if any.
  String? filename;

  /// The MIME type of the last [shareFile] call, if any.
  String? mimeType;

  /// The bytes of the last [shareFile] call, if any.
  Uint8List? bytes;

  @override
  Future<void> share(String text) async => shared.add(text);

  @override
  Future<void> shareFile({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    this.filename = filename;
    this.mimeType = mimeType;
    this.bytes = bytes;
  }
}

/// A [SessionRepository] whose chosen operations always fail.
///
/// By default [upload] throws (spec 0024's "a throwing repository never breaks
/// completion" and the upload queue keeping the record). With
/// `throwsOnList: true` the synced read fails instead (spec 0029), so the
/// "My sessions" screen takes the cloud-read-failure path.
class ThrowingSessionRepository implements SessionRepository {
  /// Creates a repository failing on the chosen operations.
  ThrowingSessionRepository({
    this.throwsOnUpload = true,
    this.throwsOnList = false,
  });

  /// Whether [upload] throws.
  final bool throwsOnUpload;

  /// Whether [list] throws a [SessionSyncException].
  final bool throwsOnList;

  /// How many times [upload] was called, throwing calls included.
  int callCount = 0;

  @override
  Future<void> upload(SessionRecord record) async {
    callCount++;
    if (throwsOnUpload) {
      throw Exception('upload failed');
    }
  }

  @override
  Future<List<SessionRecord>> list() async {
    if (throwsOnList) {
      throw const SessionSyncException('boom');
    }
    return const <SessionRecord>[];
  }

  @override
  Future<void> deleteById(String id) async {}
}
