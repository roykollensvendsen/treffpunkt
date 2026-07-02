// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the backup blob and the restore merge (spec 0106).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/backup/domain/backup.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

SessionRecord _session(String id, {int total = 90}) => SessionRecord(
  id: id,
  program: '10 m Luftpistol 60 skudd',
  total: total,
  maxTotal: 600,
  innerTens: 2,
  payload: const <String, dynamic>{'v': 1},
  capturedAt: DateTime.utc(2026, 7, 1, 18),
  placeLabel: 'Kongsberg',
);

FeltSessionRecord _felt(String id) => FeltSessionRecord(
  id: id,
  capturedAt: DateTime.utc(2026, 7, 2, 12),
  session: FeltSessionSnapshot(
    group: FeltShooterGroup.two,
    currentHold: 7,
    holds: <List<FeltPlacedShot>>[
      const <FeltPlacedShot>[
        FeltPlacedShot(dx: 38.6, dy: 97.9, figureIndex: 0, inner: true),
      ],
      for (var i = 1; i < 8; i++) const <FeltPlacedShot>[],
    ],
  ),
);

const Weapon _weapon = Weapon(
  id: 'w1',
  name: 'Min luftpistol',
  discipline: Discipline.pistol,
  caliberLabel: '4,5 mm',
  classLabel: 'Luftpistol',
);

void main() {
  final backup = Backup(
    sessions: [_session('s1')],
    feltRounds: [_felt('f1')],
    weapons: const [_weapon],
    records: const {'10 m Luftpistol 60 skudd': (points: 372, inner: 11)},
    defaultPlace: 'Løvenskioldbanen',
  );

  group('build/parse (spec 0106)', () {
    test('the blob round-trips losslessly', () {
      final json = buildBackupJson(
        backup,
        exportedAt: DateTime.utc(2026, 7, 3),
      );
      final parsed = parseBackupJson(json);

      expect(parsed.sessions.single.id, 's1');
      expect(parsed.sessions.single.total, 90);
      expect(parsed.sessions.single.payload, {'v': 1});
      expect(parsed.feltRounds.single.id, 'f1');
      expect(parsed.feltRounds.single.points, 2);
      expect(parsed.weapons.single.name, 'Min luftpistol');
      expect(
        parsed.records['10 m Luftpistol 60 skudd'],
        (points: 372, inner: 11),
      );
      expect(parsed.defaultPlace, 'Løvenskioldbanen');
    });

    test('a foreign or unversioned blob is rejected', () {
      expect(
        () => parseBackupJson(const {'kind': 'something-else'}),
        throwsFormatException,
      );
      expect(() => parseBackupJson(const {}), throwsFormatException);
    });

    test('missing sections parse as empty, broken entries are skipped', () {
      final parsed = parseBackupJson(const {
        'app': 'treffpunkt',
        'kind': 'backup',
        'version': 1,
        'sessions': [
          {'not': 'a session'},
        ],
      });
      expect(parsed.sessions, isEmpty);
      expect(parsed.feltRounds, isEmpty);
      expect(parsed.weapons, isEmpty);
      expect(parsed.records, isEmpty);
      expect(parsed.defaultPlace, isNull);
    });
  });

  group('mergeBackup (spec 0106)', () {
    test('adds only what is new, existing entries win by id', () {
      final existing = _session('s1', total: 95);
      final result = mergeBackup(
        incoming: backup,
        sessions: [existing, _session('s2')],
        feltRounds: const [],
        weapons: const [],
        records: const {},
        defaultPlace: null,
      );

      // s1 exists → the local copy wins; nothing is duplicated.
      expect(result.sessions, hasLength(2));
      expect(
        result.sessions.firstWhere((r) => r.id == 's1').total,
        95,
      );
      expect(result.newSessions, 0);
      expect(result.newFeltRounds, 1);
      expect(result.feltRounds.single.id, 'f1');
      expect(result.newWeapons, 1);
      expect(result.records['10 m Luftpistol 60 skudd'], isNotNull);
      expect(result.defaultPlace, 'Løvenskioldbanen');
    });

    test('weapons merge by name, records keep the best result', () {
      final result = mergeBackup(
        incoming: backup,
        sessions: const [],
        feltRounds: const [],
        weapons: const [
          Weapon(
            id: 'other-id',
            name: 'Min luftpistol',
            discipline: Discipline.pistol,
            caliberLabel: '4,5 mm',
            classLabel: 'Luftpistol',
          ),
        ],
        records: const {
          '10 m Luftpistol 60 skudd': (points: 380, inner: 0),
        },
        defaultPlace: 'Hjemmebanen',
      );

      // Same name → no duplicate weapon; existing default place wins.
      expect(result.weapons, hasLength(1));
      expect(result.newWeapons, 0);
      expect(result.defaultPlace, 'Hjemmebanen');
      // The better record (380 > 372) is kept.
      expect(
        result.records['10 m Luftpistol 60 skudd'],
        (points: 380, inner: 0),
      );
      expect(result.newRecords, 0);
    });
  });
}
