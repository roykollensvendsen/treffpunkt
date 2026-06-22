// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the session recording notifier: placing, moving, and advancing
// series-by-series then stage-by-stage (with a face switch).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

// Two stages on two different faces: A = precision (rings 1-10), B = rapid
// (rings 5-10); each one series of 2 shots.
const ProgramDefinition _program = ProgramDefinition(
  name: 'Test',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
    StageDefinition(
      name: 'B',
      geometry: TargetGeometry.pistol25mRapid(),
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
  ],
);
const Shot _centre = Shot(dxMm: 0, dyMm: 0);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(_program),
      ],
    );
  });
  tearDown(() => container.dispose());

  SessionRecording read() => container.read(sessionProvider);
  SessionNotifier notifier() => container.read(sessionProvider.notifier);

  test('starts on the first stage with an empty current series', () {
    final recording = read();
    expect(recording.current, isNotNull);
    expect(recording.current!.capacity, 2);
    expect(recording.current!.geometry.lowestRingValue, 1); // precision face
    expect(recording.isComplete, isFalse);
  });

  test('placing fills the current series', () {
    notifier().placeShot(_centre);
    expect(read().current!.placedCount, 1);
  });

  test('advancing seals the series and moves to the next stage (new face)', () {
    notifier()
      ..placeShot(_centre)
      ..placeShot(_centre);
    expect(read().current!.isComplete, isTrue);

    notifier().advance();
    final recording = read();
    expect(recording.isComplete, isFalse);
    expect(recording.current!.geometry.lowestRingValue, 5); // rapid face
    expect(recording.current!.placedCount, 0);
  });

  test('advancing past the last series completes the session', () {
    notifier()
      ..placeShot(_centre)
      ..placeShot(_centre)
      ..advance()
      ..placeShot(_centre)
      ..placeShot(_centre)
      ..advance();
    final recording = read();
    expect(recording.isComplete, isTrue);
    expect(recording.current, isNull);
  });

  test('advance does nothing until the current series is full', () {
    notifier()
      ..placeShot(_centre) // 1 of 2
      ..advance(); // ignored
    expect(read().current!.placedCount, 1);
    expect(read().session.currentStageIndex, 0);
  });

  test('the session carries no metadata by default', () {
    expect(read().session.metadata, isNull);
  });

  test('an overridden metadata provider is threaded into the session', () {
    final metadata = SessionMetadata(
      capturedAt: DateTime.utc(2026, 6, 21, 14, 30),
      place: const Place(label: 'Løvenskiold skytebane'),
    );
    final scoped = ProviderContainer(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(_program),
        currentSessionMetadataProvider.overrideWithValue(metadata),
      ],
    );
    addTearDown(scoped.dispose);
    expect(scoped.read(sessionProvider).session.metadata, metadata);
  });

  test('moving a placed shot in the current series', () {
    notifier()
      ..placeShot(_centre)
      ..pickUp(0)
      ..dragTo(const Shot(dxMm: 100, dyMm: 0));
    expect(read().current!.shots.single.dxMm, 100);
    expect(read().isDragging, isTrue);

    notifier().drop();
    expect(read().isDragging, isFalse);
  });
}
