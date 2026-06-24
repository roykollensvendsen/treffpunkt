<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0041 — Consented training-image collection

- **Status:** Accepted
- **Related:** spec 0039 (scan), spec 0040 (auto-detect), ADR-0023 (the consent
  + dataset design), spec 0030 (the settings/store pattern mirrored here)

## Context

The auto-detector (spec 0040) has only ever been tuned against synthetic images.
To improve it — and to later train a model — we need a **tagged database of real
target photos with their hit positions**. The scan flow already produces exactly
that at confirm time: the photo + the calibration + the **human-confirmed shots**
(gold labels). This feature captures that tuple and uploads it to a private
dataset, **opt-out (default on)**, and thanks the contributor. Decided with the
domain expert: a one-time disclosure + a persistent toggle, with self-serve
erasure as a fast-follow. GDPR basis: legitimate interest (improving detection)
on minimised, private, low-PII data with a frictionless opt-out.

## Requirements

1. **Capture at confirm.** When a signed-in shooter confirms a scan **and**
   contribution is on, build a training sample (photo + hit labels) and upload it
   best-effort. It must **never** block or delay confirming, and **never** throw.
2. **Self-describing labels.** Each sample stores the target geometry, the
   calibration and every hole in the **uploaded image's own pixels** (plus mm),
   with each hole tagged `auto`/`manual` and `edited`, so the corpus is
   reproducible from the JPEG alone and can grade the detector against human
   truth.
3. **Privacy.** Capture only when **signed in** (so the data has an owner and can
   be erased) and only when **consent is on**. Strip EXIF/GPS by re-encoding the
   JPEG. Store privately (owner-only RLS on the bucket + table).
4. **Transparency & control.** A **one-time disclosure** on the first scan
   (plain Norwegian: what's collected, why, that it's optional/on-by-default, with
   an immediate "Skru av"), a **persistent app-bar toggle**, and a privacy doc.
   Turning it off stops all future uploads.
5. **No regression.** The scan still pops the same `List<Shot>`; manual
   capture/calibrate/tap/drag/undo/auto-detect are unchanged.

## Design

- **Domain (pure):** `TrainingSample` / `TrainingHole` / `TrainingHoleSource`
  (`domain/training_sample.dart`) and a pure `buildLabel(sample, {imageWidth,
  imageHeight})` (`domain/training_label.dart`, `schemaVersion: 1`). The builder
  converts the box-space calibration + holes to image pixels via the existing
  `PhotoFit` (downscaling preserves the aspect ratio, so the field is letterboxed
  like the photo), so the label is reproducible from the uploaded JPEG. The image
  bytes never appear in the JSON.
- **Seam:** `ContributionService` (`data/contribution_service.dart`,
  best-effort, never throws) with the default `UnavailableContributionService`;
  the real `SupabaseContributionService` (the only file importing
  `supabase_flutter` + Storage) re-encodes the JPEG (`decodeImage →
  bakeOrientation → encodeJpg`, stripping EXIF), uploads to
  `training-images/<uid>/<id>.jpg`, then inserts the row. Provider +
  `runTreffpunkt`/`main` wiring.
- **Consent:** `ContributionConsentStore` (`enabled` default `true`,
  `disclosureShown` default `false`) mirroring `ThemeModeStore`; a
  `ContributionConsentNotifier` + providers seeded once in `main`; a
  `ContributionToggleButton` app-bar action; a one-time
  `ContributionDisclosureDialog`.
- **Capture wiring:** the scan screen tracks each candidate's `source`/`edited`
  (a small `_Candidate` refactor; the popped `List<Shot>` is unchanged), shows
  the disclosure once on first open, and at confirm calls `_maybeContribute`
  (gated on sign-in + consent, fire-and-forget, wrapped so it never breaks the
  pop).
- **Backend:** migration `20260624140000_training_samples.sql` — a **private**
  `training-images` bucket with owner-prefix Storage RLS, and a `training_samples`
  table with owner-only select/insert/delete RLS (`user_id` defaults to
  `auth.uid()`, `on delete cascade`). Erasure: account-delete cascades the rows;
  the Storage objects need a documented prefix-purge, and self-serve "slett mine
  bidrag" is the fast-follow (delete policies already shipped).

## Rationale

Capturing the human-confirmed scan is the cheapest possible labelling — the
shooter already did the work. Image-pixel labels reproducible from the JPEG make
the corpus portable to any training pipeline. Best-effort fire-and-forget suits
non-critical data and keeps the binary out of a durable outbox. Signed-in-only
gives every sample an owner for RLS and erasure. The one-time disclosure +
toggle makes an opt-out model transparent and reversible.

## Verification

### Unit
- `training_label_test`: schema version; self-describing geometry; box→image
  `PhotoFit` conversion of centre/scale/holes (filled and letterboxed, hand-
  computed); per-hole px+mm+source+edited; null inner-ten.
- `contribution_consent_store_test`: opt-out defaults, round-trip (in-memory +
  `shared_preferences`). `contribution_providers_test`: seed + `setEnabled` +
  `markDisclosureShown` persist.

### Widget
- `scan_target_screen_test` (fakes: `FakeContributionService`,
  `FakeAuthRepository`, consent on/off): the disclosure shows once then is gone;
  a **signed-in + consent-on** confirm contributes one sample with the right
  hole count + `source`; **signed-out** and **consent-off** contribute nothing;
  the existing scan tests stay green after the `_Candidate` refactor.
- `contribution_toggle_button_test`: turning it off flips the provider.

### Manual
Scan signed-in → a row + object appear in Supabase; toggle off → none; confirm
the uploaded JPEG carries no EXIF/GPS.

## Known limitations / next increment

Self-serve "Slett mine bidrag", a consolidated settings screen, a durable image
outbox (v1 drops on offline — acceptable for non-critical data), and the dataset
**export + human review (face-blur) + model-training** pipeline are fast-follows.
A photo may incidentally show hands/faces/surroundings (ADR-0023) — mitigated by
the private, signed-in-only, owner-scoped bucket and a review step before any
training.
