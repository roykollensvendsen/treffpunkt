// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';

/// A minimal concrete subclass, standing in for the per-feature exceptions.
class _TestSyncException extends SyncException {
  const _TestSyncException(super.cause);
}

void main() {
  group('SyncException', () {
    test('carries the underlying cause', () {
      final cause = Exception('boom');
      expect(_TestSyncException(cause).cause, same(cause));
    });

    test('toString is "<ClassName>: <cause>"', () {
      expect(
        const _TestSyncException('the table is missing').toString(),
        '_TestSyncException: the table is missing',
      );
    });

    test('the per-feature sync exceptions share the base', () {
      expect(const SessionSyncException('x'), isA<SyncException>());
      expect(const FeltSyncException('x'), isA<SyncException>());
      expect(const CompetitionSyncException('x'), isA<SyncException>());
      expect(const ForumException('x'), isA<SyncException>());
    });

    test('the per-feature toStrings keep their historical shape', () {
      expect(
        const SessionSyncException('e').toString(),
        'SessionSyncException: e',
      );
      expect(const FeltSyncException('e').toString(), 'FeltSyncException: e');
      expect(
        const CompetitionSyncException('e').toString(),
        'CompetitionSyncException: e',
      );
      expect(const ForumException('e').toString(), 'ForumException: e');
    });
  });

  group('guardSync', () {
    test('returns the task result when it succeeds', () async {
      final result = await guardSync(
        () async => 42,
        debugLabel: 'Failed to count',
        wrap: _TestSyncException.new,
      );
      expect(result, 42);
    });

    test('wraps a failure in the provided exception', () async {
      final cause = Exception('boom');
      await expectLater(
        guardSync<int>(
          () async => throw cause,
          debugLabel: 'Failed to count',
          wrap: _TestSyncException.new,
        ),
        throwsA(
          isA<_TestSyncException>().having((e) => e.cause, 'cause', cause),
        ),
      );
    });

    test('catches non-Exception throwables too', () async {
      await expectLater(
        guardSync<void>(
          () async => throw StateError('bad'),
          debugLabel: 'Failed to poke',
          wrap: _TestSyncException.new,
        ),
        throwsA(
          isA<_TestSyncException>().having(
            (e) => e.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
    });

    test(
      'debug-prints "<debugLabel>: <error>" on failure (debug mode)',
      () async {
        final printed = <String?>[];
        final previous = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        addTearDown(() => debugPrint = previous);

        await expectLater(
          guardSync<void>(
            () async => throw Exception('boom'),
            debugLabel: 'Failed to list the records',
            wrap: _TestSyncException.new,
          ),
          throwsA(isA<_TestSyncException>()),
        );

        expect(printed, ['Failed to list the records: Exception: boom']);
      },
    );

    test('does not print on success', () async {
      final printed = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = previous);

      await guardSync(
        () async => 'ok',
        debugLabel: 'Failed to fetch',
        wrap: _TestSyncException.new,
      );

      expect(printed, isEmpty);
    });
  });
}
