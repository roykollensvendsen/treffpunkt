// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// System test: boot the real app signed in (fake repo) and score a shot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:treffpunkt/bootstrap.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';

import '../test/features/auth/fake_auth_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the target centre scores a ten in the series', (
    tester,
  ) async {
    runTreffpunkt(
      FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 't', email: 'a@b.no')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 / 10'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(seriesTotalKey)).data, '0');

    await tester.tap(find.byKey(seriesTargetKey));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(seriesTotalKey)).data, '10');
  });
}
