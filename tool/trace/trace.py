# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Trace a reference image's colour regions into normalised polygons.

Usage:
    python3 tool/trace/trace.py IMAGE [--out out/trace.png] [options]

    # one region — everything that isn't paper:
    python3 tool/trace/trace.py ref.png

    # named colour regions, isolated by a sampled/target colour:
    python3 tool/trace/trace.py ref.png \\
        --region case:0.35,0.45:8 --region bullet:0.82,0.45 --eps 2.0

    # a symmetric object drawn on its side, stood upright:
    python3 tool/trace/trace.py ref.png --symmetry y --rotate 90

    # stylise to an octagon:
    python3 tool/trace/trace.py ref.png --max-verts 8

A ``--region`` is ``NAME:SPEC[:CLOSE]`` where SPEC is either ``x,y`` (a 0..1
sample point whose colour is picked from the image) or ``r,g,b`` (a target
colour), and the optional trailing integer is that region's own close in px
(bridges internal lines that split its fill; overrides ``--close``). All
regions share one normalisation box so they line up. Prints a JSON report
(aspect + per-region normalised points + fit IoU) and writes a
vector|overlay|original panel to --out (default out/trace.png). Read the panel;
judge with your eyes.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import tracelib as T


def parse_region(spec, rgb, default_close):
    # NAME:SPEC[:CLOSE] — SPEC is x,y (sample) or r,g,b (target); the optional
    # trailing integer is this region's own close (bridges internal lines).
    parts = spec.split(':')
    name = parts[0]
    nums = [float(x) for x in parts[1].split(',')]
    close = int(parts[2]) if len(parts) > 2 else default_close
    if len(nums) == 2:
        colour = T.sample(rgb, nums[0], nums[1])
    elif len(nums) == 3:
        colour = tuple(int(x) for x in nums)
    else:
        raise SystemExit(f"--region {spec!r}: SPEC must be x,y or r,g,b")
    return name, colour, close


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image')
    ap.add_argument('--region', action='append', default=[],
                    help='NAME:x,y (sample) or NAME:r,g,b (target colour)')
    ap.add_argument('--eps', type=float, default=1.5,
                    help='RDP tolerance in px (bigger = fewer vertices)')
    ap.add_argument('--tol', type=float, default=60.0,
                    help='colour-match tolerance for --region')
    ap.add_argument('--close', type=int, default=0,
                    help='bridge thin dark separators (centreline etc.) by N px')
    ap.add_argument('--keep-frac', type=float, default=1.0,
                    help='union every region blob >= this fraction of the '
                         'largest (recovers split fills / detached parts)')
    ap.add_argument('--chaikin', type=int, default=0,
                    help='Chaikin smoothing passes (rounds facets)')
    ap.add_argument('--max-verts', type=int, default=0,
                    help='raise --eps until each region has <= N vertices '
                         '(stylise to a primitive, e.g. 8 for an octagon)')
    ap.add_argument('--symmetry', choices=('x', 'y'), default=None,
                    help="mirror each region about its centre before tracing "
                         "('x' = left/right, 'y' = top/bottom)")
    ap.add_argument('--rotate', type=int, choices=(0, 90, 180, 270), default=0,
                    help='turn the emitted coords clockwise (the overlay stays '
                         'in the source orientation for verification)')
    ap.add_argument('--paper', default=None,
                    help='background colour r,g,b (default: auto from corners)')
    ap.add_argument('--out', default='out/trace.png')
    args = ap.parse_args()

    rgb = T.load_rgb(args.image)
    paper = (tuple(int(x) for x in args.paper.split(',')) if args.paper
             else T.paper_colour(rgb))

    named = []
    if args.region:
        for spec in args.region:
            name, colour, close = parse_region(spec, rgb, args.close)
            mask = T.largest_region(
                T.colour_mask(rgb, colour, args.tol),
                close_px=close, keep_frac=args.keep_frac)
            named.append((name, colour, mask))
    else:
        named.append(('outline', tuple(paper), T.largest_region(
            T.ink_mask(rgb, paper), close_px=args.close,
            keep_frac=args.keep_frac)))

    if args.symmetry:
        named = [(n, c, T.symmetrise(m, args.symmetry)) for n, c, m in named]

    polys_px = []
    for _, _, mask in named:
        if not mask.any():
            raise SystemExit('a region matched no pixels — adjust colour/tol')
        polys_px.append(T.trace(mask, eps=args.eps, chaikin_iters=args.chaikin,
                                max_verts=args.max_verts))

    box = T.union_box(polys_px)
    quarter = args.rotate // 90
    report = {'image': os.path.basename(args.image), 'paper': list(paper),
              'aspect': T.rotate_aspect(T.aspect(box), quarter), 'regions': []}
    panel_regions = []
    for (name, colour, mask), poly in zip(named, polys_px):
        norm = T.rotate_norm(T.normalise(poly, box), quarter)
        report['regions'].append({
            'name': name,
            'colour': list(colour) if args.region else None,
            'points': [[round(float(x), 4), round(float(y), 4)] for x, y in norm],
            'vertices': int(len(norm)),
            'fitIoU': T.fit_iou(poly, mask),
        })
        panel_regions.append((poly, colour if args.region else (90, 96, 104)))

    os.makedirs(os.path.dirname(args.out) or '.', exist_ok=True)
    T.panel(rgb, panel_regions, args.out)
    report['panel'] = args.out
    json.dump(report, sys.stdout, indent=2)
    print()


if __name__ == '__main__':
    main()
