# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Measurement report for one NorgesFelt hold image.

Usage: ``python analyze.py <hold_image> <holdNumber> [y0 y1]``

Auto-detects the art region (excludes the title/description text), classifies
paper/colour/black, finds the figure/plate/separator components, and for every
figure-candidate reports bbox, area, centroid, dominant colour, fitted
primitives (circle / ellipse / minimal polygon) with their RMS errors, and any
enclosed rings (holes). Prints JSON — the reconstruction agent maps these
components to figure types and fills in colours/inner rings.
"""
from __future__ import annotations

import json
import sys

import numpy as np

import feltlib as fl


def art_region(rgb, hold_colour):
    """Tight bbox around the large solid figures (drops thin text)."""
    lab = fl.classify(rgb, hold_colour)
    ink = lab != 0
    comps = fl.components(ink, min_area=30)
    if not comps:
        return 0, 0, rgb.shape[1], rgb.shape[0]
    # Keep only components that are a real fraction of the biggest one — this
    # drops title/description text (tiny) while keeping every figure/plate.
    top = int(comps[0].sum())
    big = [m for m in comps if m.sum() >= 0.06 * top and _solidity(m) > 0.2]
    if not big:
        return 0, 0, rgb.shape[1], rgb.shape[0]
    xs0, ys0, xs1, ys1 = 1e9, 1e9, 0, 0
    for m in big:
        x, y, w, h = fl.bbox(m)
        xs0, ys0 = min(xs0, x), min(ys0, y)
        xs1, ys1 = max(xs1, x + w), max(ys1, y + h)
    pad = 3
    return (max(0, int(xs0) - pad), max(0, int(ys0) - pad),
            min(rgb.shape[1], int(xs1) + pad), min(rgb.shape[0], int(ys1) + pad))


def _solidity(mask):
    x, y, w, h = fl.bbox(mask)
    return mask.sum() / (w * h)


def dominant_colour(rgb, mask):
    px = rgb[mask]
    for anchor, name in ((fl.PAPER, 'paper'), (fl.BLACK, 'black'),
                         (fl.GREEN, 'green'), (fl.RED, 'red')):
        pass
    return [int(round(v)) for v in px.mean(0)]


def _shape_fits(rgb, region):
    """Circle / ellipse / minimal-polygon fits for a filled region.

    The region comes from nearest-anchor classification, whose boundary already
    sits on the ~50%-coverage anti-aliased midline, so it is traced as-is (no
    dilation — growing it overshoots the true edge by ~1px).
    """
    x, y, w, h = fl.bbox(region)
    pts = fl.boundary_points(region)
    cx, cy, r, cerr = fl.fit_circle(pts)
    ex, ey, ea, eb, eth, emis = fl.fit_ellipse(region)
    try:
        ring = fl.contour_ring(region)
        poly = fl.rdp_closed(ring, eps=max(1.3, 0.012 * max(w, h)))
        poly_fine = fl.rdp_closed(ring, eps=max(0.7, 0.005 * max(w, h)))
    except Exception:  # noqa: BLE001 - report, don't crash the batch
        poly = poly_fine = np.zeros((0, 2))
    return {
        'bbox': [x, y, w, h],
        'area': int(region.sum()),
        'centroid': [round(float(pts[:, 0].mean()), 1),
                     round(float(pts[:, 1].mean()), 1)],
        'aspect': round(w / h, 3),
        'pcaAngleDeg': round(fl.pca_angle(region), 1),
        'fitCircle': {'cx': round(cx, 1), 'cy': round(cy, 1),
                      'r': round(r, 1), 'rms': round(cerr, 2)},
        'fitEllipse': {'cx': round(ex, 1), 'cy': round(ey, 1),
                       'a': round(ea, 1), 'b': round(eb, 1),
                       'thetaDeg': round(eth, 1), 'mismatch': emis},
        'polyMinimal': [[round(float(px), 1), round(float(py), 1)]
                        for px, py in poly],
        'polyFine': [[round(float(px), 1), round(float(py), 1)]
                     for px, py in poly_fine],
    }


def describe_figure(rgb, mask):
    """One ink component: its outer shape, colour, knockouts and inner ring.

    A component with a large enclosed hole is a *plate* with a knocked-out
    figure (e.g. a white hare in a black plate); the hole is reported as a
    knockout with its own contour + inner ring. Otherwise the component is a
    solid figure and its inner ring is measured directly.
    """
    solid = fl.fill_holes(mask)
    fill = dominant_colour(rgb, mask)
    out = _shape_fits(rgb, solid)
    out['solidity'] = round(_solidity(mask), 3)
    out['colour'] = fill
    big_holes = [hm for hm in fl.holes(mask) if hm.sum() > 0.15 * mask.sum()]
    knockouts = []
    for hm in big_holes:
        ko = _shape_fits(rgb, hm)
        ko['colour'] = dominant_colour(rgb, hm)
        ko['innerRing'] = fl.detect_inner_ring(rgb, hm, ko['colour'])
        knockouts.append(ko)
    out['knockouts'] = knockouts
    # A solid figure (no big knockout) carries its own inner-treff ring.
    out['innerRing'] = None if big_holes \
        else fl.detect_inner_ring(rgb, solid, fill)
    return out


def main():
    path, hold = sys.argv[1], int(sys.argv[2])
    rgb = fl.load_rgb(path)
    hc = fl.HOLD_COLOUR[hold]
    if len(sys.argv) >= 5:
        y0, y1 = int(sys.argv[3]), int(sys.argv[4])
        ax0, ay0, ax1, ay1 = 0, y0, rgb.shape[1], y1
    else:
        ax0, ay0, ax1, ay1 = art_region(rgb, hc)
    crop = rgb[ay0:ay1, ax0:ax1]
    lab = fl.classify(crop, hc)

    report = {
        'hold': hold, 'holdColour': list(hc),
        'imageSize': [rgb.shape[1], rgb.shape[0]],
        'artCrop': [ax0, ay0, ax1 - ax0, ay1 - ay0],
        'paper': list(fl.PAPER),
    }
    # figure candidates = large non-paper components in the art crop.
    ink = lab != 0
    min_a = max(40, ink.sum() // 300)
    figs = [m for m in fl.components(ink, min_area=min_a)]
    report['numInkComponents'] = len(figs)
    report['figures'] = [describe_figure(crop, m) for m in figs[:20]]
    # black separators: tall thin pure-black components (colour holds only).
    if hc != fl.BLACK:
        blk = lab == 2
        seps = []
        for m in fl.components(blk, min_area=20):
            x, y, w, h = fl.bbox(m)
            if h > 2.5 * w and h > 0.4 * crop.shape[0]:
                seps.append([x, y, w, h])
        report['blackSeparators'] = seps
    print(json.dumps(report, indent=1))


if __name__ == '__main__':
    main()
