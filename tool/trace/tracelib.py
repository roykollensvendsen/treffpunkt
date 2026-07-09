# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Turn a reference drawing/sketch into minimal-vertex vector polygons.

A small, self-contained companion to ``tool/felt`` for the *general* job of
tracing an icon/pictogram outline from a reference image and emitting it as a
Dart ``CustomPainter`` (see ``gen_dart.py``). The felt harness is specialised
to the NorgesFelt holds; this one knows nothing about shooting — you give it an
image and either a colour to isolate or "just the ink", and it hands back
ordered, RDP-simplified polygons normalised into a shared 0..1 box so several
colour regions of one object line up.

Pipeline: load → region mask → largest component (holes filled) → ordered
contour ring (potrace) → RDP to minimal vertices (optional n-gon / Chaikin) →
normalise into the union box. ``panel`` renders vector | overlay | original so
you can *judge with your eyes* what the numbers claim.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

WHITE = (255, 255, 255)


# --- Loading ---------------------------------------------------------------
def load_rgb(path, paper=WHITE):
    """Load *path* as an (H, W, 3) int array, flattening alpha onto *paper*."""
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im).astype(np.float64)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    bg = np.array(paper, dtype=np.float64)
    return (rgb * al + bg * (1 - al)).astype(np.int32)


def paper_colour(rgb):
    """The background colour, estimated as the median of the four corners."""
    h, w, _ = rgb.shape
    corners = np.array([rgb[0, 0], rgb[0, w - 1], rgb[h - 1, 0], rgb[h - 1, w - 1]])
    return tuple(int(v) for v in np.median(corners, axis=0))


# --- Region masks ----------------------------------------------------------
def ink_mask(rgb, paper=None, thresh=60.0):
    """Everything that isn't paper: pixels *thresh* away from the background."""
    if paper is None:
        paper = paper_colour(rgb)
    d = np.sqrt(((rgb - np.array(paper, dtype=np.float64)) ** 2).sum(-1))
    return d > thresh


def colour_mask(rgb, target, tol=60.0):
    """Pixels within Euclidean *tol* of *target* (an (r, g, b) tuple)."""
    d = np.sqrt(((rgb - np.array(target, dtype=np.float64)) ** 2).sum(-1))
    return d <= tol


def sample(rgb, x, y):
    """The colour at fractional position (*x*, *y*) in [0, 1] — for picking."""
    h, w, _ = rgb.shape
    return tuple(int(v) for v in rgb[min(int(y * h), h - 1), min(int(x * w), w - 1)])


# --- Components ------------------------------------------------------------
def components(mask, min_area=1):
    """4-connected components of *mask* (bool), each a bool array, largest first."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    for i in range(h):
        for j in range(w):
            if mask[i, j] and not seen[i, j]:
                q = deque([(i, j)])
                seen[i, j] = True
                comp = []
                while q:
                    y, x = q.popleft()
                    comp.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] \
                                and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
                if len(comp) >= min_area:
                    m = np.zeros_like(mask, bool)
                    ys = np.array([p[0] for p in comp])
                    xs = np.array([p[1] for p in comp])
                    m[ys, xs] = True
                    out.append(m)
    out.sort(key=lambda m: -int(m.sum()))
    return out


def fill_holes(mask):
    """Fill interior holes: flood the background in from the border, invert."""
    h, w = mask.shape
    outside = np.zeros_like(mask, bool)
    q = deque()
    for i in range(h):
        for j in (0, w - 1):
            if not mask[i, j] and not outside[i, j]:
                outside[i, j] = True
                q.append((i, j))
    for j in range(w):
        for i in (0, h - 1):
            if not mask[i, j] and not outside[i, j]:
                outside[i, j] = True
                q.append((i, j))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] \
                    and not outside[ny, nx]:
                outside[ny, nx] = True
                q.append((ny, nx))
    return mask | (~outside)


def dilate(mask, k=1):
    """Binary dilation by *k* 4-connected steps."""
    m = mask
    for _ in range(k):
        up = np.zeros_like(m)
        up[1:] = m[:-1]
        dn = np.zeros_like(m)
        dn[:-1] = m[1:]
        lf = np.zeros_like(m)
        lf[:, 1:] = m[:, :-1]
        rt = np.zeros_like(m)
        rt[:, :-1] = m[:, 1:]
        m = m | up | dn | lf | rt
    return m


def erode(mask, k=1):
    """Binary erosion by *k* 4-connected steps."""
    m = mask
    for _ in range(k):
        up = np.ones_like(m)
        up[1:] = m[:-1]
        dn = np.ones_like(m)
        dn[:-1] = m[1:]
        lf = np.ones_like(m)
        lf[:, 1:] = m[:, :-1]
        rt = np.ones_like(m)
        rt[:, :-1] = m[:, 1:]
        m = m & up & dn & lf & rt
    return m


def close(mask, k=1):
    """Morphological close (dilate then erode) — bridges thin dark separators
    like a centreline or a ring that splits one fill into pieces."""
    return erode(dilate(mask, k), k)


def largest_region(mask, fill=True, close_px=0, keep_frac=1.0):
    """One region from *mask*, robust to internal lines splitting a fill.

    *close_px* bridges thin dark separators (a centreline, a dimension line)
    before components are found. *keep_frac* < 1 unions every component at least
    that fraction of the largest's area, so a fill cut into a few blobs — or a
    detached part like a cartridge rim — is recovered as one region. Holes are
    filled by default.
    """
    if close_px:
        mask = close(mask, close_px)
    comps = components(mask, min_area=1)
    if not comps:
        return np.zeros_like(mask, bool)
    big = int(comps[0].sum())
    keep = [c for c in comps if int(c.sum()) >= keep_frac * big]
    out = np.zeros_like(mask, bool)
    for c in keep:
        out |= c
    return fill_holes(out) if fill else out


# --- Outline tracing -------------------------------------------------------
def contour_ring(mask):
    """Largest ordered boundary ring (x, y) of *mask* via potrace (y-down)."""
    h, w = mask.shape
    with tempfile.TemporaryDirectory() as d:
        pbm = os.path.join(d, 't.pbm')
        gj = os.path.join(d, 't.geojson')
        rows = ["".join('1' if mask[i, j] else '0' for j in range(w))
                for i in range(h)]
        with open(pbm, 'w') as fh:
            fh.write(f"P1\n{w} {h}\n" + "\n".join(rows))
        subprocess.run(['potrace', '-b', 'geojson', '-o', gj, pbm], check=True)
        data = json.load(open(gj))

    def rings(g):
        if g['type'] == 'Polygon':
            yield g['coordinates'][0]
        elif g['type'] == 'MultiPolygon':
            for poly in g['coordinates']:
                yield poly[0]
    feats = data['features'] if 'features' in data else [data]
    best, best_a = None, 0.0
    for f in feats:
        for r in rings(f['geometry']):
            pts = np.array(r, dtype=np.float64)
            area = abs(np.sum(pts[:-1, 0] * pts[1:, 1]
                              - pts[1:, 0] * pts[:-1, 1]))
            if area > best_a:
                best_a, best = area, pts
    best = best.copy()
    best[:, 1] = h - best[:, 1]  # potrace emits y-up; flip to image space.
    return best


def rdp(pts, eps):
    """Ramer–Douglas–Peucker simplification of an ordered polyline."""
    pts = np.asarray(pts, dtype=np.float64)
    if len(pts) < 3:
        return pts
    start, end = pts[0], pts[-1]
    line = end - start
    ll = np.hypot(*line)
    v = pts - start
    if ll < 1e-9:
        d = np.hypot(v[:, 0], v[:, 1])
    else:
        d = np.abs(line[0] * v[:, 1] - line[1] * v[:, 0]) / ll
    idx = int(np.argmax(d))
    if d[idx] > eps:
        left = rdp(pts[:idx + 1], eps)
        right = rdp(pts[idx:], eps)
        return np.vstack([left[:-1], right])
    return np.vstack([start, end])


def rdp_closed(ring, eps):
    """RDP for a closed ring; returns minimal vertices (open, no repeat)."""
    ring = np.asarray(ring, dtype=np.float64)
    if len(ring) > 1 and np.allclose(ring[0], ring[-1]):
        ring = ring[:-1]
    n = len(ring)
    if n <= 3:
        return ring
    i0 = 0
    d = np.hypot(*(ring - ring[i0]).T)
    i1 = int(np.argmax(d))
    a = rdp(np.vstack([ring[i0:i1 + 1]]), eps)
    b = rdp(np.vstack([ring[i1:], ring[i0:i0 + 1]]), eps)
    return np.vstack([a[:-1], b[:-1]])


def chaikin(pts, iters=1):
    """Chaikin corner-cutting on a closed polygon — rounds facets smoothly."""
    pts = np.asarray(pts, dtype=np.float64)
    for _ in range(iters):
        nxt = np.roll(pts, -1, axis=0)
        q = 0.75 * pts + 0.25 * nxt
        r = 0.25 * pts + 0.75 * nxt
        pts = np.empty((len(pts) * 2, 2))
        pts[0::2] = q
        pts[1::2] = r
    return pts


def trace(mask, eps=1.5, chaikin_iters=0):
    """Ordered, RDP-minimal outline (x, y) of *mask*'s largest filled region."""
    ring = contour_ring(mask)
    poly = rdp_closed(ring, eps)
    if chaikin_iters:
        poly = chaikin(poly, chaikin_iters)
    return poly


# --- Normalisation ---------------------------------------------------------
def union_box(polys):
    """(x0, y0, w, h) tight box enclosing every polygon in *polys*."""
    allp = np.vstack([np.asarray(p, dtype=np.float64) for p in polys])
    x0, y0 = allp.min(0)
    x1, y1 = allp.max(0)
    return float(x0), float(y0), float(x1 - x0), float(y1 - y0)


def normalise(poly, box):
    """Map (x, y) pixels into [0, 1]² fractions of *box* (x0, y0, w, h)."""
    x0, y0, w, h = box
    p = np.asarray(poly, dtype=np.float64).copy()
    p[:, 0] = (p[:, 0] - x0) / w
    p[:, 1] = (p[:, 1] - y0) / h
    return p


def aspect(box):
    """Width ÷ height of *box* — the pictogram's own proportion."""
    _, _, w, h = box
    return round(w / h, 4)


# --- Verification (IoU + overlay panel) ------------------------------------
def polygon_mask(poly, shape):
    """Rasterise an (N, 2) polygon to a bool mask of *shape* (h, w)."""
    h, w = shape
    img = Image.new('1', (w, h), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in poly], fill=1)
    return np.asarray(img, bool)


def iou(a, b):
    """Intersection-over-union of two bool masks."""
    inter = int((a & b).sum())
    union = int((a | b).sum())
    return inter / union if union else 0.0


def fit_iou(poly, mask):
    """How well the traced *poly* covers its source *mask* (1 = perfect)."""
    return round(iou(polygon_mask(poly, mask.shape), mask), 4)


def panel(rgb, regions, out_path, gap=12, bg=WHITE):
    """Write a 3-panel PNG: vector | overlay | original (left→right).

    *regions* is a list of ``(poly_px, colour)`` in image pixel space, where
    ``poly_px`` are the traced (x, y) points and ``colour`` an (r, g, b) fill.
    """
    h, w, _ = rgb.shape
    src = Image.fromarray(rgb.astype(np.uint8), 'RGB')

    vec = Image.new('RGB', (w, h), bg)
    dv = ImageDraw.Draw(vec)
    for poly, colour in regions:
        dv.polygon([tuple(p) for p in poly], fill=tuple(colour))

    over = src.copy().convert('RGBA')
    ov = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    do = ImageDraw.Draw(ov)
    for poly, _ in regions:
        do.line([tuple(p) for p in list(poly) + [poly[0]]],
                fill=(255, 0, 0, 255), width=max(1, w // 200))
    over = Image.alpha_composite(over, ov).convert('RGB')

    strip = Image.new('RGB', (w * 3 + gap * 2, h), (200, 200, 200))
    strip.paste(vec, (0, 0))
    strip.paste(over, (w + gap, 0))
    strip.paste(src, (2 * (w + gap), 0))
    strip.save(out_path)
    return out_path
