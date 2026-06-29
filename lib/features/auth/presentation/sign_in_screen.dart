// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/features/auth/domain/embedded_browser.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/settings/presentation/theme_mode_button.dart';

/// Key for the Google sign-in button (used by widget and system tests).
const Key signInWithGoogleButtonKey = ValueKey<String>(
  'signInWithGoogleButton',
);

/// Key for the "open in Safari/Chrome" warning shown in a blocked browser
/// context (in-app or standalone webview), used by tests (spec 0042).
const Key signInBrowserWarningKey = ValueKey<String>('signInBrowserWarning');

/// Key for the "copy link" action in the browser warning, used by tests.
const Key signInCopyLinkKey = ValueKey<String>('signInCopyLink');

/// The app's canonical web address, used as the copy-link fallback.
const String _canonicalUrl = 'https://roykollensvendsen.github.io/treffpunkt/';

/// Screen shown when no user is signed in.
class SignInScreen extends ConsumerWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authControllerProvider);
    final busy = action.isLoading;
    final env = ref.watch(browserEnvironmentProvider);
    final blocked = oauthBlockedHere(
      userAgent: env.userAgent,
      isStandalone: env.isStandalone,
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Treffpunkt', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 24),
                  if (blocked) ...[
                    _OpenInBrowserNotice(
                      url: env.currentUrl?.split('#').first ?? _canonicalUrl,
                    ),
                    const SizedBox(height: 20),
                  ],
                  FilledButton.icon(
                    key: signInWithGoogleButtonKey,
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Sign-in failed. Please try again.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // The user manual, reachable before signing in too (spec 0050) —
            // e.g. to read how to sign in.
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  key: helpButtonKey,
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Brukerveiledning',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpScreen(),
                    ),
                  ),
                ),
              ),
            ),
            // The theme switcher, reachable before signing in too (spec 0030).
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: ThemeModeButton(),
              ),
            ),
            // A discreet build-version footer so a user can confirm which build
            // they are running, even before signing in (spec 0028).
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: BuildVersionLabel(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A notice shown when Google sign-in is blocked by the current browser context
/// (an in-app or standalone webview): it explains why and offers a copy-link so
/// the user can paste the app into Safari or Chrome (spec 0042).
class _OpenInBrowserNotice extends StatelessWidget {
  const _OpenInBrowserNotice({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: signInBrowserWarningKey,
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Åpne i Safari eller Chrome for å logge inn',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Google tillater ikke innlogging i innebygde nettlesere (som '
            'Messenger) eller når appen åpnes fra hjemskjermen. Kopier lenken '
            'og lim den inn i Safari eller Chrome, og logg inn der.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: signInCopyLinkKey,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(content: Text('Lenke kopiert')),
                    );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Kopier lenke'),
            ),
          ),
        ],
      ),
    );
  }
}
