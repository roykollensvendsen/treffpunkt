// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

/// One placed shot on a hold, for persistence (spec 0081): its position
/// ([dx], [dy]) in the hold's pixel space and the resolved hit ([figureIndex]
/// null is a miss, [inner] whether it was an inner-zone hit).
@immutable
class FeltPlacedShot {
  /// Creates a placed shot.
  const FeltPlacedShot({
    required this.dx,
    required this.dy,
    this.figureIndex,
    this.inner = false,
  });

  /// Rebuilds a placed shot from [json].
  factory FeltPlacedShot.fromJson(Map<String, dynamic> json) => FeltPlacedShot(
    dx: (json['dx'] as num).toDouble(),
    dy: (json['dy'] as num).toDouble(),
    figureIndex: json['fig'] as int?,
    inner: json['inner'] as bool? ?? false,
  );

  /// Shot x in the hold's pixel space.
  final double dx;

  /// Shot y in the hold's pixel space.
  final double dy;

  /// Index of the figure hit, or null for a miss.
  final int? figureIndex;

  /// Whether the shot landed in the figure's inner zone.
  final bool inner;

  /// Serialises this shot.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'dx': dx,
    'dy': dy,
    'fig': figureIndex,
    'inner': inner,
  };

  @override
  bool operator ==(Object other) =>
      other is FeltPlacedShot &&
      other.dx == dx &&
      other.dy == dy &&
      other.figureIndex == figureIndex &&
      other.inner == inner;

  @override
  int get hashCode => Object.hash(dx, dy, figureIndex, inner);
}

/// A saved in-progress felt round (spec 0081): the shooter's [group], the shots
/// placed on each hold ([holds], one list per hold in course order) and which
/// hold is [currentHold]. Carries the round's session metadata (spec 0092) —
/// the chosen date/time, place and weapon — all optional so a pre-0092 round
/// still loads. A pure-Dart value type persisted as JSON.
@immutable
class FeltSessionSnapshot {
  /// Creates a session snapshot.
  const FeltSessionSnapshot({
    required this.group,
    required this.holds,
    required this.currentHold,
    this.capturedAt,
    this.placeLabel,
    this.latitude,
    this.longitude,
    this.weaponName,
  });

  /// Rebuilds a snapshot from [json].
  factory FeltSessionSnapshot.fromJson(Map<String, dynamic> json) =>
      FeltSessionSnapshot(
        group: FeltShooterGroup.values.byName(json['group'] as String),
        currentHold: json['currentHold'] as int,
        holds: <List<FeltPlacedShot>>[
          for (final hold in json['holds'] as List<dynamic>)
            <FeltPlacedShot>[
              for (final shot in hold as List<dynamic>)
                FeltPlacedShot.fromJson(shot as Map<String, dynamic>),
            ],
        ],
        capturedAt: json['capturedAt'] == null
            ? null
            : DateTime.parse(json['capturedAt'] as String),
        placeLabel: json['placeLabel'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        weaponName: json['weaponName'] as String?,
      );

  /// The shooter's group.
  final FeltShooterGroup group;

  /// The shots placed on each hold, one list per hold in course order.
  final List<List<FeltPlacedShot>> holds;

  /// The hold the shooter is currently on (0-based).
  final int currentHold;

  /// The chosen date and time of the round (spec 0092), or null on a round
  /// recorded before the setup step existed.
  final DateTime? capturedAt;

  /// Where the round was shot (spec 0092), or null when not recorded.
  final String? placeLabel;

  /// Latitude in decimal degrees, or null when no coordinates are known.
  final double? latitude;

  /// Longitude in decimal degrees, or null when no coordinates are known.
  final double? longitude;

  /// The weapon used (spec 0092), or null when not recorded.
  final String? weaponName;

  /// Total shots placed across all holds.
  int get totalShots => holds.fold(0, (sum, h) => sum + h.length);

  /// Serialises this snapshot.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'group': group.name,
    'currentHold': currentHold,
    'holds': <List<Map<String, dynamic>>>[
      for (final hold in holds)
        <Map<String, dynamic>>[for (final shot in hold) shot.toJson()],
    ],
    if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
    if (placeLabel != null) 'placeLabel': placeLabel,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (weaponName != null) 'weaponName': weaponName,
  };

  @override
  bool operator ==(Object other) =>
      other is FeltSessionSnapshot &&
      other.group == group &&
      other.currentHold == currentHold &&
      other.capturedAt == capturedAt &&
      other.placeLabel == placeLabel &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.weaponName == weaponName &&
      _holdsEqual(other.holds, holds);

  @override
  int get hashCode => Object.hash(
    group,
    currentHold,
    capturedAt,
    placeLabel,
    latitude,
    longitude,
    weaponName,
    Object.hashAll(holds.map(Object.hashAll)),
  );
}

bool _holdsEqual(
  List<List<FeltPlacedShot>> a,
  List<List<FeltPlacedShot>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}
