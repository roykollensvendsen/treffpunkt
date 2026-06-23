// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// System test: the sign-in gate walks signed-out -> signed-in -> signed-out.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:treffpunkt/bootstrap.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/sign_in_screen.dart';

import '../test/features/auth/fake_auth_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the gate walks signed-out -> signed-in -> signed-out', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    runTreffpunkt(fake);
    await tester.pumpAndSettle();

    expect(find.byKey(signInWithGoogleButtonKey), findsOneWidget);

    fake.emit(const SignedIn(AppUser(id: 't', email: 'a@b.no')));
    await tester.pumpAndSettle();
    expect(find.byKey(signInWithGoogleButtonKey), findsNothing);
    expect(find.text('10 m Air Pistol'), findsWidgets);

    fake.emit(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.byKey(signInWithGoogleButtonKey), findsOneWidget);
  });
}
