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

/// Key for the email field of the one-time-code sign-in (spec 0061).
const Key emailOtpFieldKey = ValueKey<String>('emailOtpField');

/// Key for the "send code" button of the email sign-in, used by tests.
const Key sendEmailOtpButtonKey = ValueKey<String>('sendEmailOtpButton');

/// Key for the code field of the email sign-in, used by tests.
const Key emailOtpCodeFieldKey = ValueKey<String>('emailOtpCodeField');

/// Key for the "verify code" button of the email sign-in, used by tests.
const Key verifyEmailOtpButtonKey = ValueKey<String>('verifyEmailOtpButton');

/// Key for the "change email" action of the email sign-in, used by tests.
const Key emailOtpChangeEmailKey = ValueKey<String>('emailOtpChangeEmail');

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
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
                      label: const Text('Logg på med Google'),
                    ),
                    if (action.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Innlogging feilet. Prøv igjen.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    const _OrDivider(),
                    const SizedBox(height: 16),
                    const _EmailOtpSignIn(),
                  ],
                ),
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
            'og lim den inn i Safari eller Chrome — eller logg inn med e-post '
            'nedenfor, som virker her.',
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
                      const SnackBar(content: Text('Lenke kopiert.')),
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

/// A thin "eller" separator between the Google and email sign-in options.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 280,
    child: Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('eller'),
        ),
        Expanded(child: Divider()),
      ],
    ),
  );
}

/// Passwordless sign-in with a one-time code emailed to the user (spec 0061).
///
/// A two-step flow with no OAuth redirect — the fallback for browsers where
/// Google sign-in is blocked (e.g. iOS): enter the email and request a code,
/// then enter the code to sign in. On success the auth stream flips and the
/// auth gate swaps in the app. State is local; errors are shown inline (kept
/// separate from the shared Google button error).
class _EmailOtpSignIn extends ConsumerStatefulWidget {
  const _EmailOtpSignIn();

  @override
  ConsumerState<_EmailOtpSignIn> createState() => _EmailOtpSignInState();
}

class _EmailOtpSignInState extends ConsumerState<_EmailOtpSignIn> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Skriv inn en gyldig e-postadresse.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailOtp(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Kunne ikke sende kode. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailOtp(email: _emailController.text.trim(), code: code);
      // On success the auth stream flips to signed-in; the AuthGate replaces
      // this screen, so there is nothing more to do here.
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Feil eller utløpt kode. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          if (!_codeSent) ...[
            TextField(
              key: emailOtpFieldKey,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-post',
                hintText: 'din@epost.no',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: sendEmailOtpButtonKey,
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mail_outline),
              label: const Text('Logg inn med e-post'),
            ),
          ] else ...[
            Text(
              'Vi sendte en kode til ${_emailController.text.trim()}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              key: emailOtpCodeFieldKey,
              controller: _codeController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(labelText: 'Engangskode'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: verifyEmailOtpButtonKey,
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Logg inn'),
            ),
            TextButton(
              key: emailOtpChangeEmailKey,
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _error = null;
                    }),
              child: const Text('Bytt e-post'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
