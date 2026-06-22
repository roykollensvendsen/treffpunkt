// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_gate.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/auth/presentation/sign_in_screen.dart';

import '../fake_auth_repository.dart';

Widget _gate(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    home: AuthGate(signedInBuilder: (user) => Text('hello ${user.email}')),
  ),
);

void main() {
  testWidgets('signed out shows the Google button', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(_gate(fake));
    await tester.pumpAndSettle();
    expect(find.byKey(signInWithGoogleButtonKey), findsOneWidget);
  });

  testWidgets('signed in shows the app content', (tester) async {
    final fake = FakeAuthRepository(
      initial: const SignedIn(AppUser(id: 't', email: 'a@b.no')),
    );
    addTearDown(fake.dispose);
    await tester.pumpWidget(_gate(fake));
    await tester.pumpAndSettle();
    expect(find.text('hello a@b.no'), findsOneWidget);
    expect(find.byKey(signInWithGoogleButtonKey), findsNothing);
  });

  testWidgets('tapping sign in reveals the app content', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(_gate(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(signInWithGoogleButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('hello shooter@example.no'), findsOneWidget);
  });
}
