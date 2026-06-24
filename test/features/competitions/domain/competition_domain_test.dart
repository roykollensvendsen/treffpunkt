// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the competitions domain entities (spec 0010): json round-trips
// (snake_case), Profile.fromAppUser, the insert-json shapes (owner/inviter
// omitted so the DB defaults them), and embedded-competition parsing.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

void main() {
  group('Profile', () {
    test('fromAppUser carries id, name and avatar', () {
      const user = AppUser(
        id: 'u1',
        email: 'a@b.no',
        displayName: 'Alice',
        avatarUrl: 'http://x/a.png',
      );
      final profile = Profile.fromAppUser(user);
      expect(profile.id, 'u1');
      expect(profile.displayName, 'Alice');
      expect(profile.avatarUrl, 'http://x/a.png');
    });

    test('json round-trips, including null fields', () {
      const full = Profile(id: 'u1', displayName: 'Alice', avatarUrl: 'a.png');
      expect(Profile.fromJson(full.toJson()), full);
      const sparse = Profile(id: 'u2');
      expect(Profile.fromJson(sparse.toJson()), sparse);
    });
  });

  group('Competition', () {
    test('fromJson reads a row; defaults is_public to false', () {
      final c = Competition.fromJson(const <String, dynamic>{
        'id': 'c1',
        'name': 'Cup',
        'program': '25 m NAIS fin',
        'owner_id': 'u1',
        'is_public': true,
        'created_at': '2026-06-23T10:00:00Z',
      });
      expect(c.id, 'c1');
      expect(c.program, '25 m NAIS fin');
      expect(c.ownerId, 'u1');
      expect(c.isPublic, isTrue);
      expect(c.createdAt, DateTime.utc(2026, 6, 23, 10));

      final noFlag = Competition.fromJson(const <String, dynamic>{
        'id': 'c2',
        'name': 'Cup',
        'program': 'x',
        'owner_id': 'u1',
      });
      expect(noFlag.isPublic, isFalse);
      expect(noFlag.createdAt, isNull);
    });

    test('toInsertJson omits owner_id (defaulted by the database)', () {
      const c = Competition(
        id: 'c1',
        name: 'Cup',
        program: 'x',
        ownerId: 'u1',
        isPublic: true,
      );
      final json = c.toInsertJson();
      expect(json, <String, dynamic>{
        'id': 'c1',
        'name': 'Cup',
        'program': 'x',
        'is_public': true,
      });
      expect(json.containsKey('owner_id'), isFalse);
    });
  });

  group('CompetitionMember', () {
    test('fromJson reads the row; withProfile attaches a profile', () {
      final m = CompetitionMember.fromJson(const <String, dynamic>{
        'competition_id': 'c1',
        'user_id': 'u1',
        'joined_at': '2026-06-23T10:00:00Z',
      });
      expect(m.competitionId, 'c1');
      expect(m.userId, 'u1');
      expect(m.profile, isNull);

      const profile = Profile(id: 'u1', displayName: 'Alice');
      expect(m.withProfile(profile).profile, profile);
    });
  });

  group('CompetitionInvitation', () {
    test('fromJson parses an embedded competition when present', () {
      final inv = CompetitionInvitation.fromJson(const <String, dynamic>{
        'competition_id': 'c1',
        'invited_email': 'bob@example.com',
        'invited_by': 'u1',
        'status': 'pending',
        'competitions': <String, dynamic>{
          'id': 'c1',
          'name': 'Cup',
          'program': 'x',
          'owner_id': 'u1',
        },
      });
      expect(inv.invitedEmail, 'bob@example.com');
      expect(inv.status, 'pending');
      expect(inv.competition?.name, 'Cup');
    });

    test('toInsertJson lower-cases the email and omits the inviter', () {
      const inv = CompetitionInvitation(
        competitionId: 'c1',
        invitedEmail: 'Bob@Example.com',
      );
      expect(inv.toInsertJson(), <String, dynamic>{
        'competition_id': 'c1',
        'invited_email': 'bob@example.com',
      });
    });
  });

  group('CompetitionResult', () {
    final record = SessionRecord(
      id: 's1',
      program: '10 m Air Pistol',
      capturedAt: DateTime.utc(2026, 6, 23, 10),
      total: 580,
      maxTotal: 600,
      innerTens: 5,
      payload: const <String, dynamic>{'k': 'v'},
    );

    test('fromSessionRecord carries the id, program and score', () {
      final result = CompetitionResult.fromSessionRecord(
        record,
        competitionId: 'c1',
      );
      expect(result.id, 's1');
      expect(result.competitionId, 'c1');
      expect(result.program, '10 m Air Pistol');
      expect(result.total, 580);
      expect(result.maxTotal, 600);
      expect(result.innerTens, 5);
      expect(result.userId, isNull); // the DB defaults it to auth.uid()
    });

    test('toInsertJson omits user_id and created_at', () {
      final json = CompetitionResult.fromSessionRecord(
        record,
        competitionId: 'c1',
      ).toInsertJson();
      expect(json['id'], 's1');
      expect(json['competition_id'], 'c1');
      expect(json['total'], 580);
      expect(json['max_total'], 600);
      expect(json['inner_tens'], 5);
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });

    test('fromJson reads a row; withProfile / withUser attach', () {
      final result = CompetitionResult.fromJson(const <String, dynamic>{
        'id': 's1',
        'competition_id': 'c1',
        'user_id': 'u1',
        'program': '10 m Air Pistol',
        'total': 580,
        'max_total': 600,
        'inner_tens': 5,
        'payload': <String, dynamic>{'k': 'v'},
      });
      expect(result.userId, 'u1');
      expect(result.total, 580);

      const profile = Profile(id: 'u1', displayName: 'Alice');
      expect(result.withProfile(profile).profile, profile);
      expect(result.withUser('u2').userId, 'u2');
    });
  });
}
