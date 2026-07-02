// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/browser_environment.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/auth/presentation/sign_in_screen.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';

import '../fake_auth_repository.dart';

Widget _screen(
  FakeAuthRepository fake, {
  BrowserEnvironment env = const BrowserEnvironment.empty(),
}) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(fake),
    browserEnvironmentProvider.overrideWithValue(env),
  ],
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
    expect(find.textContaining('feilet'), findsOneWidget);
  });

  testWidgets('shows the build-version stamp (spec 0028)', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(_screen(fake));

    expect(find.byKey(buildVersionKey), findsOneWidget);
    expect(find.textContaining('build '), findsOneWidget);
  });

  testWidgets('opens the user manual before signing in (spec 0050)', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(_screen(fake));

    await tester.tap(find.byKey(helpButtonKey));
    await tester.pumpAndSettle();

    // The manual's contents screen, reachable without signing in.
    expect(find.text('Brukerveiledning'), findsOneWidget);
    expect(find.byKey(manualPageTileKey('signing-in.md')), findsOneWidget);
  });

  group('email one-time code sign-in (spec 0061)', () {
    testWidgets('sends a code, then signs in with it', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      await tester.pumpWidget(_screen(fake));

      await tester.enterText(find.byKey(emailOtpFieldKey), 'kari@example.no');
      await tester.tap(find.byKey(sendEmailOtpButtonKey));
      await tester.pumpAndSettle();

      expect(fake.sendEmailOtpCallCount, 1);
      expect(fake.lastOtpEmail, 'kari@example.no');
      // The code step is now shown.
      expect(find.byKey(emailOtpCodeFieldKey), findsOneWidget);

      await tester.enterText(find.byKey(emailOtpCodeFieldKey), '123456');
      await tester.tap(find.byKey(verifyEmailOtpButtonKey));
      await tester.pumpAndSettle();

      expect(fake.currentStatus, isA<SignedIn>());
    });

    testWidgets('a wrong code shows an error and stays signed out', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      await tester.pumpWidget(_screen(fake));

      await tester.enterText(find.byKey(emailOtpFieldKey), 'kari@example.no');
      await tester.tap(find.byKey(sendEmailOtpButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(emailOtpCodeFieldKey), '000000');
      await tester.tap(find.byKey(verifyEmailOtpButtonKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('Feil'), findsOneWidget);
      expect(fake.currentStatus, isA<SignedOut>());
    });

    testWidgets('an invalid email is rejected before sending', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      await tester.pumpWidget(_screen(fake));

      await tester.enterText(find.byKey(emailOtpFieldKey), 'notanemail');
      await tester.tap(find.byKey(sendEmailOtpButtonKey));
      await tester.pumpAndSettle();

      expect(fake.sendEmailOtpCallCount, 0);
      expect(find.textContaining('gyldig e-post'), findsOneWidget);
      expect(find.byKey(emailOtpCodeFieldKey), findsNothing);
    });
  });

  group('blocked browser warning (spec 0042)', () {
    testWidgets('a normal browser shows no warning', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      await tester.pumpWidget(_screen(fake));

      expect(find.byKey(signInBrowserWarningKey), findsNothing);
      expect(find.byKey(signInWithGoogleButtonKey), findsOneWidget);
    });

    testWidgets('an in-app browser shows the open-in-Safari warning', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);
      await tester.pumpWidget(
        _screen(
          fake,
          env: const BrowserEnvironment(
            userAgent: 'Mozilla/5.0 iPhone [FBAN/MessengerForiOS;FBAV/451]',
            currentUrl: 'https://example.test/treffpunkt/#access_token=x',
          ),
        ),
      );

      expect(find.byKey(signInBrowserWarningKey), findsOneWidget);
      expect(find.byKey(signInCopyLinkKey), findsOneWidget);
      // The Google button is still present (in case of a false positive).
      expect(find.byKey(signInWithGoogleButtonKey), findsOneWidget);
    });

    testWidgets(
      'copying the link puts the fragment-free URL on the clipboard',
      (
        tester,
      ) async {
        final fake = FakeAuthRepository();
        addTearDown(fake.dispose);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          _screen(
            fake,
            env: const BrowserEnvironment(
              userAgent: 'Instagram 333.0',
              currentUrl: 'https://example.test/treffpunkt/#access_token=x',
            ),
          ),
        );
        await tester.tap(find.byKey(signInCopyLinkKey));
        await tester.pump();

        expect(copied, 'https://example.test/treffpunkt/');
      },
    );
  });
}
