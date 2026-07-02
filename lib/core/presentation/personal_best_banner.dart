// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';

/// Key for the «Ny pers!» banner (spec 0101), for tests.
const Key personalBestKey = ValueKey<String>('personalBest');

/// The «Ny pers!» celebration (spec 0101): a signal-red field on the
/// scorecard the moment a session beats the shooter's own history — the
/// "hit moment" [TreffColors.lastShot] was reserved for (spec 0100).
///
/// Shared by the ring and felt scorecards so the celebration is the same
/// everywhere. Shown only on the *live* completion screens; the historical
/// detail views never celebrate an old round again.
class PersonalBestBanner extends StatelessWidget {
  /// Creates the banner.
  const PersonalBestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final red = TreffColors.of(context).lastShot;
    return Semantics(
      label: 'Ny pers! Beste resultatet ditt på denne øvelsen så langt.',
      child: ExcludeSemantics(
        child: Container(
          key: personalBestKey,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ny pers!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Beste resultatet ditt på denne øvelsen så langt.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
