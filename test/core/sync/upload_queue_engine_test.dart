// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the generic offline-first upload-queue engine (ADR-0028),
// porting the queue scenarios of specs 0025/0029/0033 to the pure-Dart core:
// start loads-then-flushes, enqueue dedups by id and persists before
// uploading, a failed upload keeps the record queued, signed out everything
// stays queued, deleteById removes one record durably, operations run
// serially on one task chain, and every mutation is mirrored to onState.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/sync/upload_queue_engine.dart';

/// The smallest record with an id and a distinguishing payload.
class _Rec {
  const _Rec(this.id, [this.value = 0]);

  final String id;
  final int value;
}

/// One engine wired to in-memory capabilities the tests can inspect and steer.
class _Harness {
  _Harness({List<_Rec> stored = const <_Rec>[], this.signedIn = true})
    : stored = List<_Rec>.of(stored) {
    engine = UploadQueueEngine<_Rec>(
      idOf: (record) => record.id,
      load: () async => List<_Rec>.of(this.stored),
      persist: (records) async => this.stored = List<_Rec>.of(records),
      tryUpload: (record) async {
        uploadAttempts.add(record.id);
        final gate = uploadGates.remove(record.id);
        if (gate != null) await gate.future;
        if (failingIds.contains(record.id)) return false;
        uploaded.add(record);
        return true;
      },
      isSignedIn: () => signedIn,
      onState: states.add,
    );
  }

  late final UploadQueueEngine<_Rec> engine;

  /// The durable store's content (what `persist` last wrote).
  List<_Rec> stored;

  /// Whether the signed-in gate is open.
  bool signedIn;

  /// Ids whose upload fails (kept queued) until removed from this set.
  final Set<String> failingIds = <String>{};

  /// Per-id gates: an upload of a gated id parks until its completer fires.
  final Map<String, Completer<void>> uploadGates = <String, Completer<void>>{};

  /// Every upload attempt, successful or not, in order.
  final List<String> uploadAttempts = <String>[];

  /// The records that uploaded successfully, in order.
  final List<_Rec> uploaded = <_Rec>[];

  /// Every pending list the engine mirrored out, in order.
  final List<List<_Rec>> states = <List<_Rec>>[];

  List<_Rec> get pending => states.isEmpty ? const <_Rec>[] : states.last;
}

void main() {
  group('start (app start)', () {
    test(
      'loads the persisted records and flushes them when signed in',
      () async {
        final harness = _Harness(
          stored: const <_Rec>[_Rec('a', 1), _Rec('b', 2)],
        );

        await harness.engine.start();

        expect(harness.uploaded.map((r) => r.id), <String>['a', 'b']);
        expect(harness.pending, isEmpty);
        expect(harness.stored, isEmpty);
      },
    );

    test('dedups a store holding two records with one id, last wins', () async {
      final harness = _Harness(
        stored: const <_Rec>[_Rec('same', 1), _Rec('same', 9)],
        signedIn: false, // the flush no-ops, so the loaded list is observable
      );

      await harness.engine.start();

      expect(harness.pending, hasLength(1));
      expect(harness.pending.single.value, 9);
    });

    test('signed out, the loaded records stay queued untouched', () async {
      final harness = _Harness(
        stored: const <_Rec>[_Rec('a')],
        signedIn: false,
      );

      await harness.engine.start();

      expect(harness.uploadAttempts, isEmpty);
      expect(harness.pending.map((r) => r.id), <String>['a']);
      expect(harness.stored.map((r) => r.id), <String>['a']);
    });
  });

  group('enqueue', () {
    test('persists the record, then uploads it and drains the queue', () async {
      final harness = _Harness();
      // Park the upload so the moment between persist and upload is visible.
      final gate = harness.uploadGates['a'] = Completer<void>();

      final done = harness.engine.enqueue(const _Rec('a', 7));
      await pumpEventQueue();

      // Durable before (and regardless of) the upload: no record is lost if
      // the app dies mid-upload.
      expect(harness.stored.map((r) => r.id), <String>['a']);
      expect(harness.uploaded, isEmpty);

      gate.complete();
      await done;

      expect(harness.uploaded.map((r) => r.id), <String>['a']);
      expect(harness.pending, isEmpty);
      expect(harness.stored, isEmpty);
    });

    test(
      'signed out, the record stays queued and persisted (no loss)',
      () async {
        final harness = _Harness(signedIn: false);

        await harness.engine.enqueue(const _Rec('offline', 5));

        expect(harness.uploadAttempts, isEmpty);
        expect(harness.pending.map((r) => r.id), <String>['offline']);
        expect(harness.stored.map((r) => r.id), <String>['offline']);
      },
    );

    test('the same id twice keeps exactly one record, the latest', () async {
      final harness = _Harness(signedIn: false); // keep them queued
      await harness.engine.enqueue(const _Rec('dup', 30));
      await harness.engine.enqueue(const _Rec('dup', 70));

      expect(harness.pending, hasLength(1));
      expect(harness.pending.single.value, 70);
      expect(harness.stored.single.value, 70);
    });

    test(
      'a failed upload keeps the record queued for the next flush',
      () async {
        final harness = _Harness();
        harness.failingIds.add('bad');

        await harness.engine.enqueue(const _Rec('bad', 4));

        expect(harness.pending.map((r) => r.id), <String>['bad']);
        expect(harness.stored.map((r) => r.id), <String>['bad']);

        // Once the upload starts succeeding, a flush drains it.
        harness.failingIds.clear();
        await harness.engine.flush();

        expect(harness.uploaded.map((r) => r.id), <String>['bad']);
        expect(harness.pending, isEmpty);
        expect(harness.stored, isEmpty);
      },
    );
  });

  group('flush', () {
    test('uploads only the good record and keeps the failing one', () async {
      final harness = _Harness(
        stored: const <_Rec>[_Rec('ok', 1), _Rec('bad', 2)],
      );
      harness.failingIds.add('bad');

      await harness.engine.start();

      expect(harness.uploaded.map((r) => r.id), <String>['ok']);
      expect(harness.pending.map((r) => r.id), <String>['bad']);
      expect(harness.stored.map((r) => r.id), <String>['bad']);
    });

    test(
      'is a no-op when signed out (nothing dropped, nothing tried)',
      () async {
        final harness = _Harness(stored: const <_Rec>[_Rec('a')])
          ..signedIn = false;
        await harness.engine.start();

        await harness.engine.flush();

        expect(harness.uploadAttempts, isEmpty);
        expect(harness.pending.map((r) => r.id), <String>['a']);
      },
    );
  });

  group('deleteById', () {
    test('removes the record from the queue and the durable store', () async {
      final harness = _Harness(signedIn: false);
      await harness.engine.enqueue(const _Rec('a'));
      await harness.engine.enqueue(const _Rec('b'));

      await harness.engine.deleteById('a');

      expect(harness.pending.map((r) => r.id), <String>['b']);
      expect(harness.stored.map((r) => r.id), <String>['b']);
    });

    test('is a no-op for an id that is not pending', () async {
      final harness = _Harness(signedIn: false);
      await harness.engine.enqueue(const _Rec('a'));

      await harness.engine.deleteById('missing');

      expect(harness.pending.map((r) => r.id), <String>['a']);
      expect(harness.stored.map((r) => r.id), <String>['a']);
    });
  });

  group('serial task chain', () {
    test('overlapping enqueues upload each record exactly once', () async {
      final harness = _Harness();
      // A's flush parks on the gate, so B is enqueued while A is in flight.
      final gate = harness.uploadGates['A'] = Completer<void>();

      final enqueueA = harness.engine.enqueue(const _Rec('A', 11));
      await pumpEventQueue();
      expect(harness.uploaded, isEmpty); // still parked on the gate

      final enqueueB = harness.engine.enqueue(const _Rec('B', 22));
      await pumpEventQueue();
      // B waits its turn on the chain — it has not jumped ahead of A.
      expect(harness.uploaded, isEmpty);

      gate.complete();
      await enqueueA;
      await enqueueB;

      expect(
        harness.uploaded.map((r) => r.id).toList()..sort(),
        <String>['A', 'B'],
      );
      expect(
        harness.uploadAttempts.where((id) => id == 'A'),
        hasLength(1),
      );
      expect(
        harness.uploadAttempts.where((id) => id == 'B'),
        hasLength(1),
      );
      expect(harness.pending, isEmpty);
      expect(harness.stored, isEmpty);
    });

    test('a throwing task never poisons the chain for later tasks', () async {
      var loads = 0;
      final engine = UploadQueueEngine<_Rec>(
        idOf: (record) => record.id,
        // The first load (start) throws; the capability contract says
        // capabilities are best-effort, but the chain must survive anyway.
        load: () async {
          loads += 1;
          if (loads == 1) throw StateError('boom');
          return const <_Rec>[];
        },
        persist: (_) async {},
        tryUpload: (_) async => true,
        isSignedIn: () => false,
        onState: (_) {},
      );

      await expectLater(engine.start(), throwsStateError);
      // The failed predecessor is swallowed on the chain: the next operation
      // still runs to completion.
      await expectLater(engine.deleteById('x'), completes);
    });
  });

  group('state mirroring', () {
    test('every mutation is mirrored to onState, in order', () async {
      final harness = _Harness(stored: const <_Rec>[_Rec('a', 1)]);
      harness.failingIds.add('a');

      await harness.engine.start();
      expect(
        harness.states.map((s) => s.map((r) => r.id).join(',')).toList(),
        <String>['a', 'a'], // the load, then the failed flush's remainder
      );

      harness.failingIds.clear();
      await harness.engine.flush();
      expect(harness.states.last, isEmpty);
    });
  });
}
