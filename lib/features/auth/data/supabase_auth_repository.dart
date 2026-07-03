// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_repository.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';

/// [AuthRepository] backed by Supabase Google OAuth.
///
/// This is the only file that imports `supabase_flutter`. It is excluded from
/// automated tests (no real credentials) and verified by the manual checklist
/// in spec 0003.
final class SupabaseAuthRepository implements AuthRepository {
  /// Creates a repository wrapping the given Supabase [client].
  SupabaseAuthRepository(SupabaseClient client)
    : _client = client,
      _auth = client.auth;

  final SupabaseClient _client;
  final GoTrueClient _auth;

  /// Deep link the OAuth flow returns to on mobile (configured per platform).
  static const String _mobileRedirect = 'no.treffpunkt://login-callback';

  @override
  AuthStatus get currentStatus => _statusFor(_auth.currentSession);

  @override
  Stream<AuthStatus> authStateChanges() async* {
    yield currentStatus;
    yield* _auth.onAuthStateChange.map((event) => _statusFor(event.session));
  }

  @override
  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      // On the web, redirect back to the exact current URL so a `?join&token`
      // deep link survives the OAuth round-trip (spec 0048). For a plain
      // sign-in this is just the app URL, unchanged.
      redirectTo: kIsWeb ? Uri.base.toString() : _mobileRedirect,
    );
  }

  @override
  // Sends the passwordless login email; shouldCreateUser defaults to true, so a
  // first-time shooter is registered on verify. The email template must include
  // the code for the no-redirect flow (spec 0061).
  Future<void> sendEmailOtp(String email) => _auth.signInWithOtp(email: email);

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_own_account');
    // The account is gone; drop the now-orphaned local session.
    await _auth.signOut();
  }

  AuthStatus _statusFor(Session? session) {
    final user = session?.user;
    if (user == null) {
      return const SignedOut();
    }
    return SignedIn(_appUserFor(user));
  }

  AppUser _appUserFor(User user) {
    final metadata = user.userMetadata;
    return AppUser(
      id: user.id,
      email: user.email,
      displayName: metadata?['full_name'] as String?,
      avatarUrl: metadata?['avatar_url'] as String?,
    );
  }
}
