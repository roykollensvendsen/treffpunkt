# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Emit a Dart CustomPainter pictogram from a trace.py JSON report.

Usage:
    python3 tool/trace/trace.py ref.png --region ... > report.json
    python3 tool/trace/gen_dart.py report.json --name Pellet [--colour name=0xAARRGGBB ...]

Prints the ``<Name>Pictogram`` + ``_<Name>Painter`` classes that match the
shape in ``lib/core/presentation/category_pictograms.dart`` (fixed-colour,
sized from the ambient IconTheme, fitted with the shared ``_fit``/``_polyPath``
helpers already in that file). Paste it in, wire it into the picker, then
render at tile size for sign-off. Regions are painted in listed order (first =
bottom); give each a colour with ``--colour region=0xAARRGGBB``.
"""

from __future__ import annotations

import argparse
import json
import sys


# Dart reserved words that can't be a plain identifier — a region named one of
# these (e.g. "case") gets an "Outline" suffix so the emitted field compiles.
_DART_KEYWORDS = {
    'case', 'class', 'const', 'default', 'else', 'enum', 'extends', 'false',
    'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'return',
    'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while',
    'with', 'assert', 'break', 'catch', 'continue', 'do', 'rethrow',
}


def ident(name):
    """A safe lowerCamel Dart identifier for a region *name*."""
    if name in _DART_KEYWORDS:
        return f'{name}Outline'
    return name


def offsets(points):
    body = ',\n'.join(
        f'    Offset({fmt(x)}, {fmt(y)})' for x, y in points)
    return f'<Offset>[\n{body},\n  ]'


def fmt(v):
    """Whole numbers as int literals (very_good_analysis prefers_int_literals)."""
    return str(int(v)) if float(v).is_integer() else repr(round(float(v), 4))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('report')
    ap.add_argument('--name', required=True, help='PascalCase, e.g. Pellet')
    ap.add_argument('--colour', action='append', default=[],
                    help='region=0xAARRGGBB fill colour')
    args = ap.parse_args()

    rep = json.load(open(args.report))
    colours = dict(c.split('=') for c in args.colour)
    name = args.name
    regions = rep['regions']

    lines = []
    lines.append(f'/// The {name} pictogram (spec NNNN — describe it here).')
    lines.append(f'class {name}Pictogram extends StatelessWidget {{')
    lines.append(f'  /// Creates the pictogram; [size] falls back to the '
                 f'ambient [IconTheme].')
    lines.append(f'  const {name}Pictogram({{this.size, super.key}});')
    lines.append('')
    lines.append('  /// Height, defaulting to the ambient icon size (24).')
    lines.append('  final double? size;')
    lines.append('')
    lines.append(f'  /// Width ÷ height of the figure.')
    lines.append(f"  static const double aspect = {rep['aspect']};")
    for r in regions:
        lines.append('')
        lines.append(f'  /// The {r["name"]} region outline (0..1 of the box).')
        lines.append(f'  static const List<Offset> {ident(r["name"])} = '
                     f'{offsets(r["points"])};')
    lines.append('')
    lines.append('  @override')
    lines.append('  Widget build(BuildContext context) {')
    lines.append('    final side = size ?? IconTheme.of(context).size ?? 24;')
    lines.append('    return SizedBox(')
    lines.append('      width: side,')
    lines.append('      height: side,')
    lines.append(f'      child: const CustomPaint(painter: _{name}Painter()),')
    lines.append('    );')
    lines.append('  }')
    lines.append('}')
    lines.append('')
    lines.append(f'class _{name}Painter extends CustomPainter {{')
    lines.append(f'  const _{name}Painter();')
    lines.append('')
    lines.append('  @override')
    lines.append('  void paint(Canvas canvas, Size size) {')
    lines.append(f'    final rect = _fit(size, {name}Pictogram.aspect);')
    lines.append('    canvas')
    for i, r in enumerate(regions):
        col = colours.get(r['name'], '0xFF808080')
        term = ';' if i == len(regions) - 1 else ''
        lines.append(f'      ..drawPath(')
        lines.append(f'        _polyPath({name}Pictogram.{ident(r["name"])}, rect),')
        lines.append(f'        Paint()..color = const Color({col}),')
        lines.append(f'      ){term}')
    lines.append('  }')
    lines.append('')
    lines.append(f'  @override')
    lines.append(f'  bool shouldRepaint(_{name}Painter oldDelegate) => false;')
    lines.append('}')

    sys.stdout.write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
