// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/data/contribution_service.dart';
import 'package:treffpunkt/features/scoring/domain/training_sample.dart';

/// In-memory [ContributionService] for tests — records contributed samples.
class FakeContributionService implements ContributionService {
  /// The samples contributed so far, in order.
  final List<TrainingSample> contributions = <TrainingSample>[];

  @override
  Future<void> contribute(TrainingSample sample) async =>
      contributions.add(sample);
}
