// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the settings backup section (spec 0106): export shares a
// JSON blob with everything, import merges a picked file additively.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/features/backup/data/backup_file_source.dart';
import 'package:treffpunkt/features/backup/domain/backup.dart';
import 'package:treffpunkt/features/backup/presentation/backup_section.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

import '../../../support/fakes.dart';
import '../../../support/records.dart';

class _FakeFileSource implements BackupFileSource {
  _FakeFileSource(this._bytes);

  final Uint8List? _bytes;

  @override
  Future<Uint8List?> pickBackupFile() async => _bytes;
}

SessionRecord _session(String id) => sessionRecord(
  id: id,
  program: '10 m Luftpistol 60 skudd',
  total: 90,
  inner: 2,
  payload: const <String, dynamic>{'v': 1},
  capturedAt: DateTime.utc(2026, 7, 1, 18),
);

FeltSessionRecord _felt(String id) => feltSessionRecord(
  id: id,
  capturedAt: DateTime.utc(2026, 7, 2, 12),
  group: FeltShooterGroup.two,
  currentHold: 7,
  holdCount: 8,
  shot: const FeltPlacedShot(dx: 10, dy: 10, figureIndex: 0),
);

void main() {
  Widget app({
    required Sharer sharer,
    required BackupFileSource files,
    required InMemoryPendingUploadsStore pending,
    required InMemoryFeltHistoryStore feltHistory,
  }) => ProviderScope(
    overrides: [
      sharerProvider.overrideWithValue(sharer),
      backupFileSourceProvider.overrideWithValue(files),
      pendingUploadsStoreProvider.overrideWithValue(pending),
      feltHistoryStoreProvider.overrideWithValue(feltHistory),
    ],
    child: const MaterialApp(home: Scaffold(body: BackupSection())),
  );

  testWidgets('export shares one JSON file with everything (0106)', (
    tester,
  ) async {
    final sharer = RecordingSharer();
    final pending = InMemoryPendingUploadsStore();
    await pending.save([_session('s1')]);
    final feltHistory = InMemoryFeltHistoryStore();
    await feltHistory.save([_felt('f1')]);

    await tester.pumpWidget(
      app(
        sharer: sharer,
        files: _FakeFileSource(null),
        pending: pending,
        feltHistory: feltHistory,
      ),
    );
    await tester.tap(find.byKey(settingsBackupExportKey));
    await tester.pumpAndSettle();

    expect(sharer.filename, startsWith('treffpunkt-backup-'));
    expect(sharer.mimeType, 'application/json');
    final parsed = parseBackupJson(
      jsonDecode(utf8.decode(sharer.bytes!)) as Map<String, dynamic>,
    );
    expect(parsed.sessions.single.id, 's1');
    expect(parsed.feltRounds.single.id, 'f1');
    expect(find.textContaining('klar til deling'), findsOneWidget);
  });

  testWidgets('import merges additively after confirmation (0106)', (
    tester,
  ) async {
    final incoming = buildBackupJson(
      Backup(
        sessions: [_session('s1'), _session('s2')],
        feltRounds: [_felt('f1')],
        weapons: const [
          Weapon(
            id: 'w1',
            name: 'Backup-pistolen',
            discipline: Discipline.pistol,
            caliberLabel: '4,5 mm',
            classLabel: 'Luftpistol',
          ),
        ],
        records: const {'10 m Luftpistol 60 skudd': (points: 372, inner: 1)},
        defaultPlace: 'Løvenskioldbanen',
      ),
      exportedAt: DateTime.utc(2026, 7, 3),
    );
    final pending = InMemoryPendingUploadsStore();
    await pending.save([_session('s1')]); // s1 already on the device
    final feltHistory = InMemoryFeltHistoryStore();

    await tester.pumpWidget(
      app(
        sharer: RecordingSharer(),
        files: _FakeFileSource(
          Uint8List.fromList(utf8.encode(jsonEncode(incoming))),
        ),
        pending: pending,
        feltHistory: feltHistory,
      ),
    );
    await tester.tap(find.byKey(settingsBackupImportKey));
    await tester.pumpAndSettle();

    // The confirmation names the contents before anything is written.
    expect(find.textContaining('2 økter'), findsOneWidget);
    expect(await pending.load(), hasLength(1));

    await tester.tap(find.byKey(backupImportConfirmKey));
    await tester.pumpAndSettle();

    expect(await pending.load(), hasLength(2));
    expect(await feltHistory.load(), hasLength(1));
    expect(find.textContaining('Importert: 1 økter'), findsOneWidget);
  });

  testWidgets('a foreign file is rejected with a message (0106)', (
    tester,
  ) async {
    final pending = InMemoryPendingUploadsStore();
    await tester.pumpWidget(
      app(
        sharer: RecordingSharer(),
        files: _FakeFileSource(
          Uint8List.fromList(utf8.encode('{"hello": "world"}')),
        ),
        pending: pending,
        feltHistory: InMemoryFeltHistoryStore(),
      ),
    );
    await tester.tap(find.byKey(settingsBackupImportKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Fila er ikke en Treffpunkt-sikkerhetskopi.'),
      findsOneWidget,
    );
    expect(await pending.load(), isEmpty);
  });

  testWidgets('cancelling the file dialog does nothing (0106)', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        sharer: RecordingSharer(),
        files: _FakeFileSource(null),
        pending: InMemoryPendingUploadsStore(),
        feltHistory: InMemoryFeltHistoryStore(),
      ),
    );
    await tester.tap(find.byKey(settingsBackupImportKey));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
