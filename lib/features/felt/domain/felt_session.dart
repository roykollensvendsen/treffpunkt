// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// A Norwegian field-shooting class (spec 0068).
///
/// Fin / grov / militær / revolver all shoot 6 shots per hold (NSF *Reglement
/// for feltpistol*). The class sets only the shots-per-hold and the label; the
/// course (distances, figures) varies per competition and is not modelled.
enum FeltClass {
  /// Finfelt (.22).
  fin('Finfelt', 6),

  /// Grovfelt (centre-fire).
  grov('Grovfelt', 6),

  /// Militærfelt.
  militar('Militærfelt', 6),

  /// Revolverfelt.
  revolver('Revolverfelt', 6);

  const FeltClass(this.label, this.shotsPerHold);

  /// The Norwegian label shown in the app.
  final String label;

  /// Shots fired at each hold.
  final int shotsPerHold;
}

/// One hold (station) result: the [hits] on the figures and the [innerHits]
/// among them, used for the tiebreak (spec 0068).
@immutable
class FeltHold {
  /// Creates a hold result.
  const FeltHold({this.hits = 0, this.innerHits = 0});

  /// Number of hits on the hold's figures.
  final int hits;

  /// Number of those hits in an inner zone (the tiebreak).
  final int innerHits;

  @override
  bool operator ==(Object other) =>
      other is FeltHold && other.hits == hits && other.innerHits == innerHits;

  @override
  int get hashCode => Object.hash(hits, innerHits);
}

/// A field-shooting session (spec 0068): a [feltClass] and a fixed number of
/// [holds], each scored by hits (the score) and inner hits (the tiebreak).
///
/// Field shooting is scored by **hits**, not rings, and the course changes per
/// competition — so this records the result per hold, not shot positions.
@immutable
class FeltSession {
  /// Creates a session over the given [holds].
  const FeltSession({required this.feltClass, required this.holds});

  /// A fresh session with [holdCount] empty holds (10 by default).
  factory FeltSession.start(FeltClass feltClass, {int holdCount = 10}) =>
      FeltSession(
        feltClass: feltClass,
        holds: List<FeltHold>.unmodifiable(
          List<FeltHold>.filled(holdCount, const FeltHold()),
        ),
      );

  /// The class being shot.
  final FeltClass feltClass;

  /// The per-hold results, in order.
  final List<FeltHold> holds;

  /// Number of holds in the course.
  int get holdCount => holds.length;

  /// Shots fired at each hold.
  int get shotsPerHold => feltClass.shotsPerHold;

  /// The most hits possible ([holdCount] × [shotsPerHold]).
  int get maxHits => holdCount * shotsPerHold;

  /// Total hits across every hold — the score.
  int get totalHits => holds.fold(0, (sum, h) => sum + h.hits);

  /// Total inner hits across every hold — the tiebreak.
  int get totalInnerHits => holds.fold(0, (sum, h) => sum + h.innerHits);

  /// A copy with hold [index] set to [hits] / [innerHits], clamped so hits stay
  /// within [shotsPerHold] and inner hits never exceed the hold's hits.
  FeltSession withHold(int index, {required int hits, required int innerHits}) {
    final clampedHits = hits.clamp(0, shotsPerHold);
    final clampedInner = innerHits.clamp(0, clampedHits);
    final next = <FeltHold>[
      for (var i = 0; i < holds.length; i++)
        if (i == index)
          FeltHold(hits: clampedHits, innerHits: clampedInner)
        else
          holds[i],
    ];
    return FeltSession(
      feltClass: feltClass,
      holds: List<FeltHold>.unmodifiable(next),
    );
  }
}
