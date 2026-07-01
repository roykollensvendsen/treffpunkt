# /goal — Faithful vector reconstruction of the 8 NorgesFelt 2026 holds

## Goal (one sentence)
Redraw **all 8 holds** of the NorgesFelt 2026 course as **vector graphics** that
are, as closely as the source images physically allow, an exact match of the
official hold images — every figure's shape, colour, rotation, scale and
position *relative to the other figures in the hold*, the coloured target-group
(målgruppe) backing plates, the **black vertical separator lines** between
målgrupper, and each inner-treff ring — using **minimal interpolation points**.

## Ground truth
- The 8 official hold images `hold1-2026.png … hold8-2026.png` (measurement only,
  never committed — copyrighted).
- The per-figure blink images (shape + colour reference).
- Where a detail is ambiguous, research the official sources (norgesfelt.no, the
  2026 løypebeskrivelse) before guessing.

## What "match" means, per hold
1. **Målgrupper**: the correct backing plate(s) (colour + shape) the figures sit
   on, and the **black vertical separator line(s)** between adjacent målgrupper.
2. **Figures**: correct silhouette/lines; correct fill colour and the background
   it sits on (a white figure knocked out of a coloured plate vs a coloured
   figure on white); correct rotation; correct scale and relative position.
3. **Inner-treff rings**: correct centre (relative to the figure, not the bbox),
   radius, stroke and colour.
4. **Minimal vertices**: exact **circle** for circles, fitted **ellipse** for
   ovals/eggs, straight segments for straight edges, and only as many polygon
   points as the curve genuinely needs (RDP-minimised). Fewer points also fit the
   anti-aliased edge *better*, not worse.

## Method (mathematical, measurable) — the `tool/felt` harness
For each hold: **segment** paper/colour/black and find components; per figure
**fit the best primitive** (least-squares circle, moment-based ellipse, PCA
rotation, RDP polygon) and **detect the faint inner ring**; **assemble** a vector
model (`models/hold-N.json`: plates + separators + figures with transform,
colours, inner ring); **render** it anti-aliased and **diff** against the source.
Driven by a dynamic Workflow: 8 holds in parallel, each reconstructed then
**independently adversarially verified** against the image, looping until the bar
is met. A per-hold **3-panel** (vector | overlay | original) is produced for
sign-off.

## Success bar — calibrated to the image resolution
The source art is small (≈150–390 px). At that size a *mathematically perfect*
hard-edged vector still cannot exceed **≈0.95 raw IoU** — the irreducible cost of
only knowing the source edges to ±0.5 px (verified: the source's own shapes
re-rasterised score `ceiling` ≈ 0.95–0.985). So raw IoU ≥ 0.99 is **physically
impossible** and is not the target. Instead, per hold:
- **`matchScore` = IoU / ceiling ≥ 0.95** (aim 0.97) — agreement relative to the
  physical maximum,
- **boundary error median ≤ 1.5 px** (sub-pixel / 1-px faithful edges),
- **`colour` ≥ 0.90** (fills, backgrounds, lines, rings correct),
- the independent **adversarial verifier passes** the hold, and
- the 3-panel shows no discernible shape/colour/rotation/placement difference.
Confidence, not a raw-pixel count: I do not stop until I am ≥99 % sure each hold
is visually indistinguishable and every structural element (figures, colours,
rotations, relative layout, rings, separators) is right.

## Constraints
- Only reconstructed vector data + the analysis scripts go in the repo; source
  images and overlay artefacts never committed. Commit progress on
  `feat/felt-holds-vector-reconstruction`.
- **No PR** without the user's explicit approval (standing instruction). After
  approval, a separate increment wires the composed holds into the app
  (`FeltCourseScreen`) spec-first + TDD.
- Pure-Dart domain stays Flutter-free; geometry/colours live in presentation.

## Deliverables (this round — for sign-off, no PR)
- `tool/felt/` harness + `models/hold-{1..8}.json` vector models.
- A per-hold 3-panel comparison (left vector | middle overlay | right original)
  + a metrics table (matchScore / boundary px / colour / verify pass).
