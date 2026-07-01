# SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
#
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pure PIL+numpy toolkit for reconstructing the NorgesFelt 2026 holds as vectors.

No scipy/opencv. Provides: palette classification, connected components,
hole-filling, ordered-contour extraction (via potrace), primitive fitting
(least-squares circle, algebraic ellipse, PCA rotation, RDP polygon), a vector
model renderer, IoU/colour comparison, and a 3-panel comparison builder.

The vector model is a plain dict (JSON on disk); see ``render_model`` for the
schema. Coordinates are in the source art-region pixel space, so a rendered
model diffs directly against the (cropped) source image and relative figure
sizes are preserved by construction.
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

# --- Palette (measured from the official hold images) -----------------------
PAPER = (255, 255, 255)
BLACK = (16, 16, 16)
GREEN = (0, 104, 63)
RED = (237, 28, 36)
HOLD_COLOUR = {
    1: BLACK, 2: GREEN, 3: RED, 4: BLACK,
    5: GREEN, 6: RED, 7: BLACK, 8: GREEN,
}


def load_rgb(path):
    """Load *path* as an (H, W, 3) int array, flattening any alpha onto paper."""
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im).astype(np.float64)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    paper = np.array(PAPER, dtype=np.float64)
    return (rgb * al + paper * (1 - al)).astype(np.int32)


# --- Classification & components -------------------------------------------
def classify(rgb, hold_colour):
    """Label each pixel 0=paper, 1=hold-colour, 2=black by nearest anchor.

    For black holds pass ``hold_colour=BLACK`` so classes 1 and 2 coincide.
    """
    anchors = np.array([PAPER, hold_colour, BLACK], dtype=np.float64)
    d = np.sqrt(((rgb[:, :, None, :] - anchors[None, None]) ** 2).sum(-1))
    return d.argmin(-1).astype(np.int8)


def components(mask, min_area=1):
    """All 4-connected components of *mask* (bool), each as a bool array.

    Returned largest-first; components smaller than *min_area* are dropped.
    """
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
    """Fill interior holes: flood the background from the border, invert."""
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


def holes(mask):
    """Interior background regions of *mask* (its enclosed holes), as components."""
    filled = fill_holes(mask)
    return components(filled & ~mask, min_area=8)


def erode(mask, k=1):
    """Binary erosion by *k* 4-connected steps."""
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
        m = m & up & dn & lf & rt
    return m


def dilate(mask, k=1):
    """Binary dilation by *k* 4-connected steps."""
    m = mask
    for _ in range(k):
        out = m.copy()
        out[1:] |= m[:-1]
        out[:-1] |= m[1:]
        out[:, 1:] |= m[:, :-1]
        out[:, :-1] |= m[:, 1:]
        m = out
    return m


def detect_inner_ring(rgb, region, fill, erode_px=4, dev=35):
    """Find a faint inner-treff ring inside *region* filled with colour *fill*.

    The rings are thin, low-contrast circles (a grey ring on white, a dark ring
    on black), so we erode the region to drop its own outline, take pixels that
    deviate from *fill*, and least-squares fit a circle. Returns None if no
    clean circle is present.
    """
    inner = erode(region, erode_px)
    if inner.sum() < 20:
        inner = erode(region, max(1, erode_px // 2))
    d = np.sqrt(((rgb.astype(np.float64) - np.array(fill, float)) ** 2).sum(-1))
    ring = inner & (d > dev)
    ys, xs = np.where(ring)
    if len(xs) < 15:
        return None
    pts = np.column_stack([xs, ys]).astype(np.float64)
    cx, cy, r, err = fit_circle(pts)
    if r < 3 or err > 0.30 * r:
        return None
    return {'cx': round(cx, 1), 'cy': round(cy, 1), 'r': round(r, 1),
            'rms': round(err, 2), 'n': int(len(xs)),
            'devMean': round(float(d[ring].mean()), 1)}


# --- Geometry helpers -------------------------------------------------------
def bbox(mask):
    """(x, y, w, h) bounding box of the True pixels."""
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), \
        int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)


def boundary_points(mask):
    """Unordered (x, y) boundary pixels: True with a False 4-neighbour."""
    m = mask
    up = np.zeros_like(m)
    up[1:] = m[:-1]
    dn = np.zeros_like(m)
    dn[:-1] = m[1:]
    lf = np.zeros_like(m)
    lf[:, 1:] = m[:, :-1]
    rt = np.zeros_like(m)
    rt[:, :-1] = m[:, 1:]
    edge = m & ~(up & dn & lf & rt)
    ys, xs = np.where(edge)
    return np.column_stack([xs, ys]).astype(np.float64)


def contour_ring(mask):
    """Largest ordered boundary ring (x, y) of *mask* via potrace."""
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
    # potrace emits y-up; flip back to image (y-down) space.
    best = best.copy()
    best[:, 1] = h - best[:, 1]
    return best


def pca_angle(mask):
    """Orientation (deg) of the mask's principal axis, in [-90, 90)."""
    ys, xs = np.where(mask)
    pts = np.column_stack([xs, ys]).astype(np.float64)
    pts -= pts.mean(0)
    cov = np.cov(pts.T)
    vals, vecs = np.linalg.eigh(cov)
    vx, vy = vecs[:, np.argmax(vals)]
    return float(np.degrees(np.arctan2(vy, vx)))


def fit_circle(pts):
    """Kåsa least-squares circle. Returns (cx, cy, r, rms_error)."""
    x, y = pts[:, 0], pts[:, 1]
    a = np.column_stack([2 * x, 2 * y, np.ones_like(x)])
    b = x * x + y * y
    (cx, cy, c), *_ = np.linalg.lstsq(a, b, rcond=None)
    r = float(np.sqrt(c + cx * cx + cy * cy))
    err = float(np.sqrt(np.mean((np.hypot(x - cx, y - cy) - r) ** 2)))
    return float(cx), float(cy), r, err


def fit_ellipse(mask):
    """Moment-based ellipse fit of a filled region *mask* (bool array).

    For a uniformly filled ellipse the pixel covariance is ``diag(a²/4, b²/4)``
    in the principal frame, so the semi-axes are ``2·sqrt(eigenvalue)``. This is
    far more stable than an algebraic boundary fit near-circular shapes.
    Returns (cx, cy, a, b, theta_deg, area_mismatch) with a>=b.
    """
    ys, xs = np.where(mask)
    pts = np.column_stack([xs, ys]).astype(np.float64)
    c = pts.mean(0)
    cov = np.cov((pts - c).T)
    vals, vecs = np.linalg.eigh(cov)
    order = np.argsort(vals)[::-1]
    vals, vecs = vals[order], vecs[:, order]
    a = 2.0 * float(np.sqrt(max(vals[0], 0)))
    b = 2.0 * float(np.sqrt(max(vals[1], 0)))
    theta = float(np.degrees(np.arctan2(vecs[1, 0], vecs[0, 0])))
    # area mismatch between the fitted ellipse and the region (0 = perfect).
    fig = {'type': 'ellipse',
           'params': {'cx': float(c[0]), 'cy': float(c[1]),
                      'a': a, 'b': b, 'theta': theta}}
    poly = _figure_polygon(fig)
    em = _polygon_mask(poly, mask.shape)
    mismatch = 1.0 - iou(em, mask)
    return float(c[0]), float(c[1]), a, b, theta, round(mismatch, 4)


def _polygon_mask(poly, shape):
    """Rasterise an (N,2) polygon to a bool mask of *shape* (h, w)."""
    h, w = shape
    img = Image.new('1', (w, h), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in poly], fill=1)
    return np.asarray(img, bool)


def rdp(pts, eps):
    """Ramer–Douglas–Peucker simplification of an ordered polyline/ring."""
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
        # perpendicular distance via the 2-D cross product (numpy 2 dropped
        # np.cross for 2-vectors).
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
    # anchor the two farthest-apart points so RDP sees the full loop.
    i0 = 0
    d = np.hypot(*(ring - ring[i0]).T)
    i1 = int(np.argmax(d))
    a = rdp(np.vstack([ring[i0:i1 + 1]]), eps)
    b = rdp(np.vstack([ring[i1:], ring[i0:i0 + 1]]), eps)
    return np.vstack([a[:-1], b[:-1]])


# --- Rendering --------------------------------------------------------------
def _figure_polygon(fig, steps=96):
    """Convert a figure dict to an (N, 2) outline in image space."""
    t = fig['type']
    p = fig['params']
    if t == 'circle':
        a = np.linspace(0, 2 * np.pi, steps, endpoint=False)
        return np.column_stack([p['cx'] + p['r'] * np.cos(a),
                                p['cy'] + p['r'] * np.sin(a)])
    if t == 'ellipse':
        a = np.linspace(0, 2 * np.pi, steps, endpoint=False)
        ex, ey = p['a'] * np.cos(a), p['b'] * np.sin(a)
        th = np.radians(p['theta'])
        ct, st = np.cos(th), np.sin(th)
        return np.column_stack([p['cx'] + ct * ex - st * ey,
                                p['cy'] + st * ex + ct * ey])
    # polygon: explicit points, optionally rotated about their centroid.
    pts = np.asarray(p['points'], dtype=np.float64)
    th = np.radians(p.get('theta', 0.0))
    if abs(th) > 1e-9:
        c = pts.mean(0)
        ct, st = np.cos(th), np.sin(th)
        r = pts - c
        pts = c + np.column_stack([ct * r[:, 0] - st * r[:, 1],
                                   st * r[:, 0] + ct * r[:, 1]])
    return pts


def render_model(model, scale=1):
    """Render a hold vector model to a PIL RGB image.

    Schema (all coords in source art-region pixels)::

        {"size":[W,H], "paper":[r,g,b],
         "plates":[{"rect":[x,y,w,h],"color":[r,g,b],"radius":px}],
         "figures":[{"type":"circle|ellipse|polygon","params":{...},
                     "fill":[r,g,b],
                     "inner":{"cx":,"cy":,"r":,"strokeW":,"color":[r,g,b]}}],
         "separators":[{"rect":[x,y,w,h]}]}   # black vertical lines
    """
    w, h = model['size']
    img = Image.new('RGB', (w * scale, h * scale),
                    tuple(model.get('paper', PAPER)))
    dr = ImageDraw.Draw(img)

    def sc(seq):
        return [v * scale for v in seq]
    for pl in model.get('plates', []):
        x, y, pw, ph = sc(pl['rect'])
        rad = pl.get('radius', 0) * scale
        col = tuple(pl['color'])
        if rad:
            dr.rounded_rectangle([x, y, x + pw, y + ph], rad, fill=col)
        else:
            dr.rectangle([x, y, x + pw, y + ph], fill=col)
    for fig in model.get('figures', []):
        poly = _figure_polygon(fig) * scale
        dr.polygon([tuple(pt) for pt in poly], fill=tuple(fig['fill']))
        inner = fig.get('inner')
        if inner:
            cx, cy, r = inner['cx'] * scale, inner['cy'] * scale, \
                inner['r'] * scale
            sw = max(1, int(round(inner.get('strokeW', 1.5) * scale)))
            dr.ellipse([cx - r, cy - r, cx + r, cy + r],
                       outline=tuple(inner['color']), width=sw)
    for sep in model.get('separators', []):
        x, y, sw, sh = sc(sep['rect'])
        dr.rectangle([x, y, x + sw, y + sh], fill=tuple(sep.get('color', BLACK)))
    return img


# --- Comparison -------------------------------------------------------------
def _ink_mask(rgb):
    """Non-paper pixels (anything meaningfully darker/other than paper)."""
    d = np.sqrt(((rgb - np.array(PAPER)) ** 2).sum(-1))
    return d > 40


def iou(a, b):
    """Intersection-over-union of two bool masks."""
    inter = int((a & b).sum())
    union = int((a | b).sum())
    return inter / union if union else 1.0


def strip_small(rgb, model_ink=None, keep_frac=0.12, floor=400):
    """Blank small non-paper components the model doesn't explain (distance
    labels like "25m"/"5m", which are printed on the sheet but are not
    målgruppe elements — the app shows distance on its own).

    Model-aware: a component is removed only if it is small *and* barely
    overlaps the rendered model, so every real figure the model drew (even a
    tiny circle or bowling pin) is kept; only unmatched text is dropped.
    """
    mask = _ink_mask(rgb)
    comps = components(mask, min_area=1)
    if not comps:
        return rgb
    top = int(comps[0].sum())
    out = rgb.copy()
    for c in comps:
        small = c.sum() < max(floor, keep_frac * top)
        if not small:
            continue
        matched = model_ink is not None and \
            (c & model_ink).sum() > 0.15 * c.sum()
        if not matched:
            out[c] = np.array(PAPER)
    return out


def _ink_coverage(rgb, thresh=60.0):
    """Soft ink coverage in [0, 1]: 0 = paper, 1 = fully non-paper.

    A ramp over *thresh* so anti-aliased edge pixels contribute partially — the
    same way the source was rasterised, making a pixel-accurate vector score
    near 1.0 instead of being penalised for its hard edges.
    """
    d = np.sqrt(((rgb.astype(np.float64) - np.array(PAPER, float)) ** 2).sum(-1))
    return np.clip(d / thresh, 0.0, 1.0)


SUPERSAMPLE = 3


def _aa_render(model, size):
    """Render the model supersampled then box-filter down for anti-aliasing."""
    big = render_model(model, scale=SUPERSAMPLE)
    return np.asarray(big.resize(size, Image.LANCZOS)).astype(np.float64)


def _chamfer(target):
    """Approx Euclidean distance (px) from every cell to the nearest True in
    *target*, via a two-pass chamfer transform (3-4 weights)."""
    big = 1e9
    d = np.where(target, 0.0, big)
    h, w = d.shape
    for i in range(h):
        for j in range(w):
            m = d[i, j]
            if i > 0:
                m = min(m, d[i - 1, j] + 1)
                if j > 0:
                    m = min(m, d[i - 1, j - 1] + 1.41421)
                if j < w - 1:
                    m = min(m, d[i - 1, j + 1] + 1.41421)
            if j > 0:
                m = min(m, d[i, j - 1] + 1)
            d[i, j] = m
    for i in range(h - 1, -1, -1):
        for j in range(w - 1, -1, -1):
            m = d[i, j]
            if i < h - 1:
                m = min(m, d[i + 1, j] + 1)
                if j > 0:
                    m = min(m, d[i + 1, j - 1] + 1.41421)
                if j < w - 1:
                    m = min(m, d[i + 1, j + 1] + 1.41421)
            if j < w - 1:
                m = min(m, d[i, j + 1] + 1)
            d[i, j] = m
    return d


def _edges(cov):
    """Boundary pixels of a coverage map (the 0.5 isocontour)."""
    return boundary_points((cov > 0.5))


def boundary_error(ra, sa):
    """Symmetric boundary distance (px) between two coverage maps.

    For each edge pixel of one, distance to the nearest edge of the other;
    returns median and 95th-percentile over both directions. Resolution-
    meaningful: <1px median == sub-pixel faithful.
    """
    ea = (ra > 0.5)
    eb = (sa > 0.5)
    if not ea.any() or not eb.any():
        return {'median': 0.0, 'p95': 0.0}
    da = _chamfer(boundary_mask(ea))
    db = _chamfer(boundary_mask(eb))
    pa = boundary_mask(ea)
    pb = boundary_mask(eb)
    both = np.concatenate([db[pa], da[pb]])
    return {'median': round(float(np.median(both)), 2),
            'p95': round(float(np.percentile(both, 95)), 2)}


def boundary_mask(mask):
    """Bool mask of *mask*'s 4-connected boundary pixels."""
    up = np.zeros_like(mask)
    up[1:] = mask[:-1]
    dn = np.zeros_like(mask)
    dn[:-1] = mask[1:]
    lf = np.zeros_like(mask)
    lf[:, 1:] = mask[:, :-1]
    rt = np.zeros_like(mask)
    rt[:, :-1] = mask[:, 1:]
    return mask & ~(up & dn & lf & rt)


def ceiling_iou(source_rgb):
    """Best soft-IoU any hard-edged vector can reach for this source.

    The source's own >50%-coverage mask, re-rasterised through the same
    supersample→downsample path. The residual below 1.0 is the irreducible
    penalty for only knowing the source edges to ±0.5px, so real
    reconstructions are scored relative to this, not to 1.0.
    """
    sa = _ink_coverage(source_rgb.astype(np.float64))
    h, w = sa.shape
    hard = Image.fromarray(((sa > 0.5).astype(np.uint8) * 255))
    big = hard.resize((w * SUPERSAMPLE, h * SUPERSAMPLE), Image.NEAREST)
    aa = np.asarray(big.resize((w, h), Image.LANCZOS)).astype(np.float64) / 255
    return float(np.minimum(aa, sa).sum() / max(np.maximum(aa, sa).sum(), 1))


def compare(model, source_rgb):
    """Shape/colour agreement of a model against a source art crop.

    Renders anti-aliased (supersampled). Returns ``iou`` (soft), ``ceiling``
    (max reachable at this resolution), ``matchScore`` = iou/ceiling (1.0 =
    physically perfect), ``boundaryPx`` (median/p95 edge distance) and
    ``colour`` (fraction of covered pixels whose colour matches within 60).
    """
    h, w = source_rgb.shape[:2]
    rendered = _aa_render(model, (w, h))
    source_rgb = strip_small(source_rgb, model_ink=_ink_mask(rendered))
    ra = _ink_coverage(rendered)
    sa = _ink_coverage(source_rgb.astype(np.float64))
    soft_iou = float(np.minimum(ra, sa).sum() / max(np.maximum(ra, sa).sum(), 1))
    ceil = ceiling_iou(source_rgb)
    both = (ra > 0.5) & (sa > 0.5)
    if both.sum():
        cd = np.sqrt(((rendered - source_rgb) ** 2).sum(-1))
        colour_ok = float((cd[both] < 60).mean())
    else:
        colour_ok = 1.0
    return {'iou': round(soft_iou, 4), 'ceiling': round(ceil, 4),
            'matchScore': round(soft_iou / ceil, 4),
            'boundaryPx': boundary_error(ra, sa),
            'colour': round(colour_ok, 4)}


def panel(model, source_rgb, gap=12):
    """3-panel image: left=vector, middle=vector-over-source, right=source."""
    vec = render_model(model, scale=SUPERSAMPLE).resize(
        (source_rgb.shape[1], source_rgb.shape[0]), Image.LANCZOS)
    stripped = strip_small(source_rgb, model_ink=_ink_mask(np.asarray(vec)))
    src = Image.fromarray(stripped.astype(np.uint8))
    over = Image.blend(src.convert('RGB'), vec, 0.5)
    w, h = src.size
    out = Image.new('RGB', (w * 3 + gap * 2, h), (255, 255, 255))
    out.paste(vec, (0, 0))
    out.paste(over, (w + gap, 0))
    out.paste(src.convert('RGB'), (2 * (w + gap), 0))
    return out
