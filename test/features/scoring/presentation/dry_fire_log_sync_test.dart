// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

const _signedIn = SignedIn(AppUser(id: 'u1'));
const _signedOut = SignedOut();

/// Returns a fixed auth status, so a test can be signed in or out without a
/// real backend.
class _StubAuth extends AuthStatusNotifier {
  _StubAuth(this._status);
  final AuthStatus _status;
  @override
  AsyncValue<AuthStatus> build() => AsyncData<AuthStatus>(_status);
}

/// A repository whose [list] always fails, to prove a failed pull never empties
/// the local log.
class _FailingListRepository extends InMemoryDryFireRepository {
  @override
  Future<List<DryFireEntry>> list() async =>
      throw const DryFireSyncException('boom');
}

DryFireEntry _entry(String id, {int pulls = 20, int day = 20}) => DryFireEntry(
  id: id,
  recordedAt: DateTime(2026, 7, day),
  discipline: DryFireDiscipline.presisjon,
  triggerPulls: pulls,
);

ProviderContainer _container({
  required AuthStatus auth,
  required DryFireStore store,
  required DryFireRepository repository,
}) {
  var counter = 0;
  final container = ProviderContainer(
    overrides: [
      dryFireStoreProvider.overrideWithValue(store),
      dryFireRepositoryProvider.overrideWithValue(repository),
      sessionIdGeneratorProvider.overrideWithValue(() => 'id-${counter++}'),
      dryFireClockProvider.overrideWithValue(() => DateTime(2026, 7, 27, 9)),
      authStateChangesProvider.overrideWith(() => _StubAuth(auth)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('DryFireLog sync (spec 0162)', () {
    test('signed out, register uploads nothing', () async {
      final store = InMemoryDryFireStore();
      final repository = InMemoryDryFireRepository();
      final container = _container(
        auth: _signedOut,
        store: store,
        repository: repository,
      );
      await container.read(dryFireLogProvider.future);

      await container
          .read(dryFireLogProvider.notifier)
          .register(DryFireDiscipline.presisjon, 25);

      expect(await store.load(), hasLength(1));
      expect(await repository.list(), isEmpty);
    });

    test('signed in, register uploads the new entry', () async {
      final repository = InMemoryDryFireRepository();
      final container = _container(
        auth: _signedIn,
        store: InMemoryDryFireStore(),
        repository: repository,
      );
      await container.read(dryFireLogProvider.future);

      await container
          .read(dryFireLogProvider.notifier)
          .register(DryFireDiscipline.duell, 30);

      final uploaded = await repository.list();
      expect(uploaded, hasLength(1));
      expect(uploaded.single.triggerPulls, 30);
    });

    test('sync backs up local entries and merges remote ones', () async {
      final store = InMemoryDryFireStore();
      await store.save([_entry('local', day: 10)]);
      final repository = InMemoryDryFireRepository();
      await repository.upload([_entry('remote', day: 25)]);

      final container = _container(
        auth: _signedIn,
        store: store,
        repository: repository,
      );
      await container.read(dryFireLogProvider.future);

      await container.read(dryFireLogProvider.notifier).sync();

      final merged = container.read(dryFireLogProvider).requireValue;
      expect(merged.map((e) => e.id).toSet(), {'local', 'remote'});
      // The local entry was backed up too.
      expect((await repository.list()).map((e) => e.id).toSet(), {
        'local',
        'remote',
      });
      // And the merged log was persisted.
      expect((await store.load()).map((e) => e.id).toSet(), {
        'local',
        'remote',
      });
    });

    test('a failed list leaves the local log intact', () async {
      final store = InMemoryDryFireStore();
      await store.save([_entry('local')]);
      final container = _container(
        auth: _signedIn,
        store: store,
        repository: _FailingListRepository(),
      );
      await container.read(dryFireLogProvider.future);

      await container.read(dryFireLogProvider.notifier).sync();

      expect(
        container.read(dryFireLogProvider).requireValue.single.id,
        'local',
      );
    });
  });
}
