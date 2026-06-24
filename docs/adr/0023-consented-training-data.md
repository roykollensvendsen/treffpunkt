<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0023: Collect consented training data, opt-out, to improve hole detection

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

The heuristic hole detector (spec 0040, ADR-0022) has only been tuned against
synthetic images — it has never seen a real photo. Improving it, and eventually
training a model, needs a corpus of **real target photos with their hit
positions**. The scan flow (spec 0039) already produces that at confirm time: the
photo + the calibration + the shooter's confirmed shots. We want to collect it
**opt-out (default on)**, tied to the scan/auto-detect feature, on web + mobile,
without weakening the project's privacy posture or its lean, testable
architecture.

## Decision

- **Capture the human-confirmed scan as a labelled sample**, the cheapest
  possible labelling: the shooter already marked and verified the holes. Every
  confirmed scan contributes — including fully-manual ones, which are the best
  labels — with each hole tagged `auto`/`manual` and `edited`, so the corpus can
  also **grade the detector against human truth**.
- **Label in the uploaded image's own pixels.** `buildLabel` converts the
  box-space calibration and holes to image pixels via `PhotoFit` (downscaling
  preserves aspect ratio, so the field is letterboxed exactly like the photo), so
  a label is reproducible from the JPEG alone — portable to any training pipeline,
  independent of the phone screen. The geometry block makes each sample
  self-describing (target type, calibre, rings). `schemaVersion` is the forward-
  compat hinge.
- **Opt-out with transparency (GDPR: legitimate interest).** Default on, with a
  **one-time disclosure** on the first scan (plain Norwegian: what's collected,
  why, that it's optional, with an immediate "Skru av") and a **persistent
  toggle**; turning it off stops all future uploads. This is defensible for an
  opt-out model *because* the data is minimised, private and the user is told
  plainly and can stop it in one tap.
- **Data minimisation & ownership.** Re-encode the JPEG (`decodeImage →
  bakeOrientation → encodeJpg`) to **strip EXIF/GPS**. Capture **only when signed
  in** — so every sample has an owner (RLS) and can be erased — and only when
  consent is on. Store **privately**: a `public=false` bucket and owner-prefix
  Storage RLS, plus owner-only RLS on the `training_samples` table.
- **Best-effort, fire-and-forget.** Training data is non-critical and the images
  are large, so there is no durable outbox (which would mean binary persistence):
  the upload fires `unawaited` after the scan pops, gated on sign-in + consent,
  and the seam never throws. A dropped contribution costs nothing.
- **A `ContributionService` seam** (the ADR-0015 pattern) confines
  `supabase_flutter` + the Storage API to one file; the default is a no-op and
  tests inject a fake, so the scan screen and the label builder are fully
  testable with no backend.

## Consequences

- A real, labelled, growing corpus is collected from day one, on every platform,
  with one migration and no new runtime dependency.
- The label builder, consent store and capture gating are unit-/widget-testable
  with fakes; the Supabase impl stays out of tests.
- **Erasure:** account deletion cascades the rows but **not** the Storage objects
  — those need a documented prefix-purge (`docs/dev/deploy.md`). Self-serve "slett
  mine bidrag" is a fast-follow (the delete RLS policies ship now).
- **Residual privacy risk:** a target photo can incidentally capture hands, a
  face, a range backdrop or a results slip with a name. Mitigations: the bucket is
  private and owner-scoped, capture is signed-in-only and never published, the
  disclosure lets users decline, and a **human review / face-blur pass** must
  precede any model training on the corpus. This residual risk is the main reason
  the bucket is strictly private.

## Alternatives considered

- **Hard opt-in / explicit consent screen:** rejected per the product decision —
  a transparent opt-out (disclosure + toggle) on minimised, private data is the
  chosen balance; the disclosure still gives a one-tap decline.
- **Anonymous capture (no sign-in):** rejected — no owner means no RLS scoping
  and no erasure path, and a less-private bucket. Signed-in-only is strictly
  better for privacy.
- **A durable image outbox** (documents-dir + index, retried on restart): rejected
  for v1 — real engineering (write/cleanup/quota/tests) for droppable data; the
  session outbox's `shared_preferences` medium is wrong for large binaries.
- **Bundling the image into the session payload:** rejected — bloats the critical
  session sync with non-critical binaries.
