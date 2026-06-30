// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// The shape of a field-shooting figure (spec 0068).
///
/// Geometric shapes are drawn parametrically; the three animal silhouettes are
/// traced vector outlines (see `felt_animal_paths.dart`). Every figure carries
/// an inner zone (the innertreff circle).
enum FeltFigureType {
  /// A circle (the C13 / C20 / C25 figures).
  circle('Sirkel'),

  /// A triangle, apex up.
  triangle('Trekant'),

  /// A hexagon.
  hexagon('Sekskant'),

  /// An oval / ellipse.
  oval('Oval'),

  /// An egg shape.
  egg('Egg'),

  /// A tall narrow stripe (størenstripe).
  stripe('Størenstripe'),

  /// A bowling pin (bowlingkjegle).
  bowlingPin('Bowlingkjegle'),

  /// A reduced human figure (1/6).
  reducedFigure('1/6'),

  /// A sitting hare (traced).
  hare('Hare'),

  /// A wolf head (traced).
  wolfHead('Ulvehode'),

  /// A ptarmigan (traced).
  ptarmigan('Rype');

  const FeltFigureType(this.label);

  /// The Norwegian label.
  final String label;
}

/// One figure on a hold (spec 0068): a [type] at a real size in centimetres,
/// with an optional display [name] (e.g. `C13`, `Stor oval`) and the inner-zone
/// diameter ([innerCm]).
@immutable
class FeltFigure {
  /// Creates a figure.
  const FeltFigure(
    this.type, {
    required this.widthCm,
    required this.heightCm,
    this.name,
    double? innerCm,
  }) : innerCm = innerCm ?? 0;

  /// A circle figure ([diameterCm]); the C-figures use this.
  factory FeltFigure.circle(
    double diameterCm, {
    String? name,
    double? innerCm,
  }) => FeltFigure(
    FeltFigureType.circle,
    widthCm: diameterCm,
    heightCm: diameterCm,
    name: name ?? 'C${diameterCm.toStringAsFixed(0)}',
    innerCm: innerCm,
  );

  /// The figure's shape.
  final FeltFigureType type;

  /// Real width in centimetres.
  final double widthCm;

  /// Real height in centimetres.
  final double heightCm;

  /// A display name, or `null` to use the [type] label.
  final String? name;

  /// The inner-zone (innertreff) diameter in centimetres; `0` to derive a
  /// default from the figure size.
  final double innerCm;

  /// The inner-zone diameter to draw, falling back to a share of the smaller
  /// dimension when [innerCm] is unset.
  double get effectiveInnerCm =>
      innerCm > 0 ? innerCm : 0.42 * (widthCm < heightCm ? widthCm : heightCm);

  /// The label to show.
  String get displayName => name ?? type.label;
}
