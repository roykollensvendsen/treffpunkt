// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

ProviderContainer _container(DryFireStore store) {
  var counter = 0;
  final container = ProviderContainer(
    overrides: [
      dryFireStoreProvider.overrideWithValue(store),
      sessionIdGeneratorProvider.overrideWithValue(() => 'id-${counter++}'),
      dryFireClockProvider.overrideWithValue(
        () => DateTime(2026, 7, 27, 9, 30),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('DryFireLog (spec 0161)', () {
    test('starts from the persisted log', () async {
      final store = InMemoryDryFireStore();
      await store.save([
        DryFireEntry(
          id: 'seed',
          recordedAt: DateTime(2026, 7, 20),
          discipline: DryFireDiscipline.duell,
          triggerPulls: 10,
        ),
      ]);
      final container = _container(store);

      final entries = await container.read(dryFireLogProvider.future);
      expect(entries.single.id, 'seed');
    });

    test('register appends an entry and persists it', () async {
      final store = InMemoryDryFireStore();
      final container = _container(store);
      await container.read(dryFireLogProvider.future);

      await container
          .read(dryFireLogProvider.notifier)
          .register(DryFireDiscipline.presisjon, 25);

      final state = container.read(dryFireLogProvider).requireValue;
      expect(state, hasLength(1));
      expect(state.single.discipline, DryFireDiscipline.presisjon);
      expect(state.single.triggerPulls, 25);
      // Persisted, so a fresh log would read it back.
      expect(await store.load(), hasLength(1));
    });

    test('rejects a non-positive count', () async {
      final store = InMemoryDryFireStore();
      final container = _container(store);
      await container.read(dryFireLogProvider.future);

      await container
          .read(dryFireLogProvider.notifier)
          .register(DryFireDiscipline.duell, 0);

      expect(container.read(dryFireLogProvider).requireValue, isEmpty);
      expect(await store.load(), isEmpty);
    });
  });
}
