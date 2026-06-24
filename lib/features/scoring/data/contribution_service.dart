// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/training_sample.dart';

/// Uploads a consented training [TrainingSample] to the dataset (spec 0041),
/// independent of any backend.
///
/// Best-effort and **never throws**: contributing training data is
/// non-critical, so a failure or an unconfigured backend is silently a no-op
/// and never blocks confirming a scan. The seam keeps the scan screen testable
/// with a fake and confines `supabase_flutter` + the Storage API to one file
/// (the ADR-0015 pattern).
// ignore: one_member_abstracts — a deliberate seam, not an accidental wrapper.
abstract interface class ContributionService {
  /// Uploads [sample]'s photo and hit labels. Best-effort; returns without
  /// error on any failure.
  Future<void> contribute(TrainingSample sample);
}

/// A [ContributionService] that never contributes.
///
/// The default binding until the real backend-backed service is wired (spec
/// 0041); it keeps the feature inert in tests and on an unconfigured app, and
/// keeps `supabase_flutter` out of the default provider.
class UnavailableContributionService implements ContributionService {
  /// Creates the always-unavailable service.
  const UnavailableContributionService();

  @override
  Future<void> contribute(TrainingSample sample) async {}
}
