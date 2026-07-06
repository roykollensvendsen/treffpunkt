// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The offline-first upload-queue algorithm (ADR-0028), shared by every
/// feature that keeps finished records durable locally and uploads them when
/// possible (the ring queue of spec 0025 today; felt sync as a follow-up).
///
/// Pure Dart and framework-free: the engine owns the *algorithm* — the serial
/// task chain, dedup-by-id, persist-before-upload, keep-on-failure — while the
/// feature injects its *capabilities* (how to load, persist and upload its
/// record type, whether a user is signed in, and where to mirror the pending
/// list). That keeps the queue semantics tested once, here, and lets a
/// feature's Riverpod notifier shrink to a thin shell of closures.
///
/// The pending list is deduplicated by id (enqueuing the same id twice keeps
/// one, the latest winning — an idempotent upsert). Every operation is
/// **best-effort by contract**: the injected capabilities are expected to
/// swallow their own errors (a throwing predecessor is additionally swallowed
/// on the chain so it can never poison later tasks), a failed upload simply
/// leaves the record queued for the next flush, and persisting *before*
/// uploading is what guarantees no record is ever lost.
///
/// All mutating operations run **serially** on a single task chain
/// ([_run]/[_tail]), so the asynchronous [start], an [enqueue] and a [flush]
/// can never interleave: no record is double-uploaded and no race drops one.
/// Each task is a single pass, so the queue cannot spin (ADR-0013).
class UploadQueueEngine<T> {
  /// Creates an engine over the feature's injected capabilities.
  UploadQueueEngine({
    required this._idOf,
    required this._load,
    required this._persist,
    required this._tryUpload,
    required this._isSignedIn,
    required this._onState,
  });

  /// The stable identity of a record — the dedup and [deleteById] key.
  final String Function(T record) _idOf;

  /// Loads the persisted pending list (app start). Expected best-effort: an
  /// unreadable store should yield an empty list rather than throw.
  final Future<List<T>> Function() _load;

  /// Persists the pending list durably. Expected best-effort: a write failure
  /// should be swallowed (the in-memory list is authoritative this run).
  final Future<void> Function(List<T> records) _persist;

  /// Uploads one record — including any fan-out (e.g. a competition-result
  /// submission) — returning whether **everything** succeeded. Expected to
  /// swallow its own errors and return false, leaving the record queued.
  final Future<bool> Function(T record) _tryUpload;

  /// Whether a user is currently signed in; false gates every flush.
  final bool Function() _isSignedIn;

  /// Mirrors every new pending list out (e.g. into a Riverpod notifier's
  /// state), called synchronously on each mutation.
  final void Function(List<T> pending) _onState;

  /// The tail of the serial task chain; `null` when idle.
  Future<void>? _tail;

  /// The records still waiting to upload; the engine's authoritative list.
  List<T> _pending = <T>[];

  /// Loads any records persisted by a previous run and flushes them (app
  /// start). Chained first by callers, so the load completes before any
  /// [enqueue] runs against the loaded list.
  Future<void> start() => _run(_loadThenFlush);

  /// Enqueues [record], replacing any pending record with the same id,
  /// persists the list, then flushes.
  ///
  /// Dedup-by-id keeps the upsert semantics of the whole pipeline: a record
  /// enqueued twice stays one record. Persisting **before** the upload is what
  /// guarantees no loss: the record is durable the instant it is enqueued,
  /// even if the upload then fails or the app dies mid-upload.
  Future<void> enqueue(T record) => _run(() async {
    _setPending(
      _dedupById(<T>[
        for (final pending in _pending)
          if (_idOf(pending) != _idOf(record)) pending,
        record,
      ]),
    );
    await _persist(_pending);
    await _flushOnce();
  });

  /// Removes the pending record [id] from the queue and its durable store,
  /// run on the serial chain so it never races a flush.
  ///
  /// A no-op for an id that is not pending. Persisting the remainder is what
  /// makes the removal durable across a restart.
  Future<void> deleteById(String id) => _run(() async {
    _setPending(
      _dedupById(<T>[
        for (final pending in _pending)
          if (_idOf(pending) != id) pending,
      ]),
    );
    await _persist(_pending);
  });

  /// Attempts to upload every pending record, dropping the ones that succeed
  /// and keeping the ones that fail.
  ///
  /// A no-op when signed out (the records stay queued, unchanged). One pass
  /// over the pending list, run on the serial chain so it never overlaps
  /// another operation: the queue cannot spin (ADR-0013) and a record is
  /// never double-uploaded.
  Future<void> flush() => _run(_flushOnce);

  /// Runs [task] after any in-flight operation, keeping all mutations serial.
  ///
  /// Chaining on [_tail] (and swallowing a failed predecessor so one failure
  /// cannot poison the chain) means the asynchronous load, an [enqueue] and a
  /// [flush] execute one at a time, in order — no interleaving, no race.
  Future<void> _run(Future<void> Function() task) {
    final previous = _tail ?? Future<void>.value();
    final next = previous.then((_) => task());
    _tail = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  /// Loads the persisted pending list (deduplicated), then flushes it.
  Future<void> _loadThenFlush() async {
    _setPending(_dedupById(await _load()));
    await _flushOnce();
  }

  /// One flush pass: upload each pending record, drop the ones that succeed
  /// and keep the ones that fail, then persist the remainder.
  Future<void> _flushOnce() async {
    if (!_isSignedIn()) return;
    final remaining = <T>[];
    for (final record in _pending) {
      if (!await _tryUpload(record)) {
        remaining.add(record);
      }
    }
    _setPending(remaining);
    await _persist(remaining);
  }

  /// Updates the authoritative pending list and mirrors it out.
  void _setPending(List<T> records) {
    _pending = records;
    _onState(records);
  }

  /// Keeps the last record per id, preserving order — an idempotent upsert.
  List<T> _dedupById(List<T> records) {
    final byId = <String, T>{};
    for (final record in records) {
      byId[_idOf(record)] = record;
    }
    return List<T>.unmodifiable(byId.values);
  }
}
