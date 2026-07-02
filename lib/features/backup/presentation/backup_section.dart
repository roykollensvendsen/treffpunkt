// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/features/backup/data/backup_file_source.dart';
import 'package:treffpunkt/features/backup/domain/backup.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/settings/presentation/default_place_providers.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';

/// Key for the "Eksporter til fil" tile (spec 0106), for tests.
const Key settingsBackupExportKey = ValueKey<String>('settingsBackupExport');

/// Key for the "Importer fra fil" tile (spec 0106), for tests.
const Key settingsBackupImportKey = ValueKey<String>('settingsBackupImport');

/// Key for the import confirmation dialog's confirm action, for tests.
const Key backupImportConfirmKey = ValueKey<String>('backupImportConfirm');

/// The settings page's «Sikkerhetskopi» section (spec 0106): export
/// everything to a JSON file through the share sheet, and restore from one —
/// additive, never destructive.
class BackupSection extends ConsumerWidget {
  /// Creates the section.
  const BackupSection({super.key});

  /// Gathers everything worth backing up: local stores plus — best-effort —
  /// the account copies, deduplicated by id.
  Future<Backup> _collect(WidgetRef ref) async {
    final pending = await ref.read(pendingUploadsStoreProvider).load();
    var synced = const <SessionRecord>[];
    try {
      synced = await ref.read(sessionRepositoryProvider).list();
    } on Object {
      // Offline or signed out: the local sessions stand alone.
    }
    final sessions = mergeMySessions(
      synced: synced,
      pending: pending,
    ).map((entry) => entry.record).toList();

    final localRounds = await ref.read(feltHistoryStoreProvider).load();
    var syncedRounds = const <FeltSessionRecord>[];
    try {
      syncedRounds = await ref.read(feltSessionRepositoryProvider).list();
    } on Object {
      // Best-effort, as above.
    }
    final rounds = mergeFeltRounds(local: localRounds, synced: syncedRounds);

    return Backup(
      sessions: sessions,
      feltRounds: rounds,
      weapons: await ref.read(weaponStoreProvider).load(),
      records: ref.read(personalRecordsProvider),
      defaultPlace: ref.read(defaultPlaceProvider),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final sharer = ref.read(sharerProvider);
    try {
      final backup = await _collect(ref);
      final now = DateTime.now();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await sharer.shareFile(
        filename: 'treffpunkt-backup-$stamp.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(
          utf8.encode(jsonEncode(buildBackupJson(backup, exportedAt: now))),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sikkerhetskopi med ${backup.sessions.length} økter og '
            '${backup.feltRounds.length} feltrunder er klar til deling.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!kReleaseMode) debugPrint('Backup export failed: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Eksporten feilet. Prøv igjen.')),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await ref.read(backupFileSourceProvider).pickBackupFile();
    if (bytes == null) return;

    Backup incoming;
    try {
      incoming = parseBackupJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fila er ikke en Treffpunkt-sikkerhetskopi.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importere sikkerhetskopi?'),
        content: Text(
          'Fila inneholder ${incoming.sessions.length} økter, '
          '${incoming.feltRounds.length} feltrunder og '
          '${incoming.weapons.length} våpen. Alt du har fra før beholdes; '
          'bare det som mangler legges til.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: backupImportConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final pendingStore = ref.read(pendingUploadsStoreProvider);
    final feltStore = ref.read(feltHistoryStoreProvider);
    final result = mergeBackup(
      incoming: incoming,
      sessions: await pendingStore.load(),
      feltRounds: await feltStore.load(),
      weapons: await ref.read(weaponStoreProvider).load(),
      records: ref.read(personalRecordsProvider),
      defaultPlace: ref.read(defaultPlaceProvider),
    );

    // The pending queue is the durable inbox (spec 0025): restored sessions
    // upload themselves to the account on the next flush, idempotent by id.
    await pendingStore.save(result.sessions);
    await feltStore.save(result.feltRounds);
    ref.read(weaponsProvider.notifier).replaceAll(result.weapons);
    final recordsNotifier = ref.read(personalRecordsProvider.notifier);
    for (final entry in result.records.entries) {
      recordsNotifier.setRecord(entry.key, entry.value);
    }
    final place = result.defaultPlace;
    if (place != null && ref.read(defaultPlaceProvider) == null) {
      ref.read(defaultPlaceProvider.notifier).set(place);
    }
    ref
      ..invalidate(storedPendingProvider)
      ..invalidate(feltHistoryProvider);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Importert: ${result.newSessions} økter, '
          '${result.newFeltRounds} feltrunder, '
          '${result.newWeapons} våpen.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ListTile(
        key: settingsBackupExportKey,
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Eksporter til fil'),
        subtitle: const Text(
          'Del øktene, våpnene og rekordene dine som én fil.',
        ),
        onTap: () => unawaited(_export(context, ref)),
      ),
      ListTile(
        key: settingsBackupImportKey,
        leading: const Icon(Icons.file_upload_outlined),
        title: const Text('Importer fra fil'),
        subtitle: const Text('Gjenopprett fra en sikkerhetskopi.'),
        onTap: () => unawaited(_import(context, ref)),
      ),
    ],
  );
}
