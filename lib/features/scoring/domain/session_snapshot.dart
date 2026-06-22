// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// A serializable picture of an in-progress recording (spec 0009).
///
/// Holds the [session] (program by name, optional weapon and metadata, and the
/// sealed series grouped by stage) together with the [current] in-progress
/// series' shots. Pure value type: it converts to and from a JSON-able map
/// **without** serializing any target geometry — on [SessionSnapshot.fromJson]
/// the program is resolved from [ProgramCatalogue] and every series is rebuilt
/// from the stage geometries, so a stored recording always scores against the
/// current tables.
@immutable
class SessionSnapshot {
  /// Creates a snapshot of [session] with the [current] in-progress series, or
  /// `null` when the session is complete.
  const SessionSnapshot({required this.session, this.current});

  /// Rebuilds a snapshot from a [json] map produced by [toJson].
  ///
  /// Throws a [FormatException] when the stored program name is not in
  /// [ProgramCatalogue], so a corrupt or stale record fails loudly instead of
  /// mis-scoring.
  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final name = json['program'] as String;
    final program = ProgramCatalogue.byName(name);
    if (program == null) {
      throw FormatException('unknown program "$name"');
    }

    final sealedJson = json['sealedSeriesByStage'] as List<dynamic>;
    final sealedByStage = <List<Series>>[
      for (var stageIndex = 0; stageIndex < program.stages.length; stageIndex++)
        <Series>[
          for (final seriesJson in sealedJson[stageIndex] as List<dynamic>)
            _seriesFrom(
              program.stages[stageIndex],
              seriesJson as List<dynamic>,
            ),
        ],
    ];

    var session = Session.start(
      program,
      metadata: _metadataFrom(json['metadata']),
      weapon: _weaponFrom(json['weapon']),
    );
    for (final stageSeries in sealedByStage) {
      for (final series in stageSeries) {
        session = session.sealSeries(series);
      }
    }

    final currentJson = json['current'];
    final current = currentJson == null
        ? null
        : _seriesFrom(session.currentStage!, currentJson as List<dynamic>);
    return SessionSnapshot(session: session, current: current);
  }

  /// The session so far (sealed series grouped by stage).
  final Session session;

  /// The in-progress series' shots, or `null` when the session is complete.
  final Series? current;

  /// A JSON-able map of this snapshot; geometry is intentionally omitted.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'program': session.program.name,
      'weapon': _weaponJson(session.weapon),
      'metadata': _metadataJson(session.metadata),
      'sealedSeriesByStage': <List<dynamic>>[
        for (final stageSeries in session.sealedSeriesByStage)
          <dynamic>[
            for (final series in stageSeries) _seriesJson(series),
          ],
      ],
      'current': current == null ? null : _seriesJson(current!),
    };
  }

  static Series _seriesFrom(StageDefinition stage, List<dynamic> shotsJson) {
    var series = Series(
      geometry: stage.geometry,
      capacity: stage.shotsPerSeries,
    );
    for (final shotJson in shotsJson) {
      series = series.placeShot(_shotFrom(shotJson as Map<String, dynamic>));
    }
    return series;
  }

  static List<Map<String, double>> _seriesJson(Series series) =>
      <Map<String, double>>[for (final shot in series.shots) _shotJson(shot)];

  static Shot _shotFrom(Map<String, dynamic> json) => Shot(
    dxMm: (json['dxMm'] as num).toDouble(),
    dyMm: (json['dyMm'] as num).toDouble(),
  );

  static Map<String, double> _shotJson(Shot shot) => <String, double>{
    'dxMm': shot.dxMm,
    'dyMm': shot.dyMm,
  };

  static Weapon? _weaponFrom(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return Weapon(
      id: map['id'] as String,
      name: map['name'] as String,
      discipline: _disciplineFrom(map['discipline'] as String),
      caliberLabel: map['caliberLabel'] as String,
      classLabel: map['classLabel'] as String,
      make: map['make'] as String?,
      model: map['model'] as String?,
      notes: map['notes'] as String?,
    );
  }

  static Map<String, dynamic>? _weaponJson(Weapon? weapon) {
    if (weapon == null) return null;
    return <String, dynamic>{
      'id': weapon.id,
      'name': weapon.name,
      'discipline': weapon.discipline.name,
      'caliberLabel': weapon.caliberLabel,
      'classLabel': weapon.classLabel,
      'make': weapon.make,
      'model': weapon.model,
      'notes': weapon.notes,
    };
  }

  static SessionMetadata? _metadataFrom(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return SessionMetadata(
      capturedAt: DateTime.parse(map['capturedAt'] as String),
      place: _placeFrom(map['place']),
    );
  }

  static Map<String, dynamic>? _metadataJson(SessionMetadata? metadata) {
    if (metadata == null) return null;
    return <String, dynamic>{
      'capturedAt': metadata.capturedAt.toIso8601String(),
      'place': _placeJson(metadata.place),
    };
  }

  static Place? _placeFrom(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return Place(
      label: map['label'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  static Map<String, dynamic>? _placeJson(Place? place) {
    if (place == null) return null;
    return <String, dynamic>{
      'label': place.label,
      'latitude': place.latitude,
      'longitude': place.longitude,
    };
  }

  static Discipline _disciplineFrom(String name) =>
      Discipline.values.firstWhere((value) => value.name == name);

  @override
  bool operator ==(Object other) =>
      other is SessionSnapshot &&
      _sessionEquals(other.session) &&
      _seriesEquals(current, other.current);

  @override
  int get hashCode => Object.hash(
    session.program.name,
    session.weapon,
    session.metadata,
    current?.placedCount,
  );

  bool _sessionEquals(Session other) {
    if (session.program.name != other.program.name) return false;
    if (session.weapon != other.weapon) return false;
    if (session.metadata != other.metadata) return false;
    final mine = session.sealedSeriesByStage;
    final theirs = other.sealedSeriesByStage;
    if (mine.length != theirs.length) return false;
    for (var stage = 0; stage < mine.length; stage++) {
      if (mine[stage].length != theirs[stage].length) return false;
      for (var s = 0; s < mine[stage].length; s++) {
        if (!_seriesEquals(mine[stage][s], theirs[stage][s])) return false;
      }
    }
    return true;
  }

  static bool _seriesEquals(Series? a, Series? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.capacity != b.capacity) return false;
    if (a.geometry.name != b.geometry.name) return false;
    if (a.shots.length != b.shots.length) return false;
    for (var i = 0; i < a.shots.length; i++) {
      if (a.shots[i].dxMm != b.shots[i].dxMm ||
          a.shots[i].dyMm != b.shots[i].dyMm) {
        return false;
      }
    }
    return true;
  }
}
