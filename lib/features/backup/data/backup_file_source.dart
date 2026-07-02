// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picks a backup file to restore from (spec 0106). A seam so the import
/// flow is testable without a real file dialog, and so `file_picker` is
/// confined to one file.
// ignore: one_member_abstracts — a deliberate seam, not an accidental wrapper.
abstract interface class BackupFileSource {
  /// Opens a file dialog and returns the chosen file's bytes, or null when
  /// the user cancels (or no dialog is available).
  Future<Uint8List?> pickBackupFile();
}

/// The default binding: no file dialog (tests, unsupported platforms).
class UnavailableBackupFileSource implements BackupFileSource {
  /// Creates the no-op source.
  const UnavailableBackupFileSource();

  @override
  Future<Uint8List?> pickBackupFile() async => null;
}

/// A [BackupFileSource] backed by `file_picker` (web + mobile + desktop).
class FilePickerBackupFileSource implements BackupFileSource {
  /// Creates the file_picker-backed source.
  const FilePickerBackupFileSource();

  @override
  Future<Uint8List?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      // On web the path is meaningless; the bytes are what we read.
      withData: true,
    );
    return result?.files.single.bytes;
  }
}

/// The app's [BackupFileSource]; `main()` overrides it with the
/// `file_picker`-backed one.
final backupFileSourceProvider = Provider<BackupFileSource>(
  (ref) => const UnavailableBackupFileSource(),
);
