// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the share/join link (spec 0048): building a link from the app
// base + competition + token, and parsing a deep link back into a join intent.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/competitions/domain/join_link.dart';

void main() {
  group('competitionJoinLink', () {
    test(
      'appends ?join&token, preserving scheme/host/path, dropping fragment',
      () {
        final link = competitionJoinLink(
          Uri.parse('https://app.example/treffpunkt/#/old'),
          competitionId: 'c1',
          token: 'tok-123',
        );
        expect(link.scheme, 'https');
        expect(link.host, 'app.example');
        expect(link.path, '/treffpunkt/');
        expect(link.queryParameters, <String, String>{
          'join': 'c1',
          'token': 'tok-123',
        });
        expect(link.hasFragment, isFalse);
      },
    );
  });

  group('parseJoinIntent', () {
    test('reads join + token', () {
      final intent = parseJoinIntent(
        Uri.parse('https://app.example/?join=c1&token=tok-123'),
      );
      expect(intent, isNotNull);
      expect(intent!.competitionId, 'c1');
      expect(intent.token, 'tok-123');
    });

    test('is null when either is missing or empty', () {
      expect(parseJoinIntent(Uri.parse('https://app.example/')), isNull);
      expect(
        parseJoinIntent(Uri.parse('https://app.example/?join=c1')),
        isNull,
      );
      expect(
        parseJoinIntent(Uri.parse('https://app.example/?token=t')),
        isNull,
      );
      expect(
        parseJoinIntent(Uri.parse('https://app.example/?join=&token=t')),
        isNull,
      );
    });

    test('round-trips a built link', () {
      final link = competitionJoinLink(
        Uri.parse('https://app.example/treffpunkt/'),
        competitionId: 'abc',
        token: 'xyz',
      );
      final intent = parseJoinIntent(link);
      expect(intent?.competitionId, 'abc');
      expect(intent?.token, 'xyz');
    });
  });
}
