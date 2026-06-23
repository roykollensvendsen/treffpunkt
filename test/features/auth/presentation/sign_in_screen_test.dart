// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/auth/presentation/sign_in_screen.dart';

import '../fake_auth_repository.dart';

Widget _screen(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: const MaterialApp(home: SignInScreen()),
);

void main() {
  testWidgets('shows a spinner while signing in', (tester) async {
    final fake = FakeAuthRepository()
      ..signInDelay = const Duration(milliseconds: 100);
    addTearDown(fake.dispose);
    await tester.pumpWidget(_screen(fake));

    await tester.tap(find.byKey(signInWithGoogleButtonKey));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('shows an error when sign-in fails', (tester) async {
    final fake = FakeAuthRepository()..failNextSignIn = true;
    addTearDown(fake.dispose);
    await tester.pumpWidget(_screen(fake));

    await tester.tap(find.byKey(signInWithGoogleButtonKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('failed'), findsOneWidget);
  });

  testWidgets('shows the build-version stamp (spec 0028)', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(_screen(fake));

    expect(find.byKey(buildVersionKey), findsOneWidget);
    expect(find.textContaining('build '), findsOneWidget);
  });
}
