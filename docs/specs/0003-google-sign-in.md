# Spec 0003 — Google sign-in via Supabase

- **Status:** Accepted
- **Related:** ADR-0002 (Supabase), ADR-0003 (Riverpod), ADR-0010 (secrets/config)

## Context

ADR-0002 chose Supabase for backend/auth and the original brief needs Google
sign-in for multi-user competitions, scoreboards and leaderboards. Increment 0
and spec 0002 shipped a single-user target-scoring feature with no identity.

Spec 0003 introduces authentication: a signed-out user sees a "Sign in with
Google" screen; after signing in they reach the app (today's target screen,
later the competition surfaces). Real Google OAuth client IDs and a live Supabase
project are not available in CI, so the feature must be **fully testable
headlessly behind an `AuthRepository` seam**, with the credential-touching code
isolated in one file and verified manually.

## Requirements

1. A signed-out user sees a sign-in screen with a "Sign in with Google" button
   (stable key `Key('signInWithGoogleButton')`).
2. Tapping the button starts Google sign-in via Supabase; on success the app
   shows the signed-in content instead of the sign-in screen.
3. The signed-in/out truth comes from the auth-state **stream**
   (`onAuthStateChange`), never from the launch-only `Future<bool>` of
   `signInWithOAuth`.
4. Signing out returns the user to the sign-in screen.
5. Sign-in failures surface as an error (button stops spinning, message shown)
   and never crash the app; the status stays signed-out.
6. While a sign-in/out action is in flight the UI shows a loading state.
7. An already-authenticated user reopening the app lands directly on signed-in
   content with no sign-in flash (initial status seeded from `currentStatus`).
8. The domain and presentation layers import no `supabase_flutter` /
   `google_sign_in`; all platform/credential code lives in
   `SupabaseAuthRepository` (data layer).
9. The whole feature is testable against a `FakeAuthRepository` with zero
   network/credential access; `SupabaseAuthRepository` is verified manually.
10. No secret is committed (see ADR-0010); the publishable/anon key is injected
    as per-environment config, not hardcoded.
11. Every new file carries the SPDX header and doc comments and passes
    `very_good_analysis` (explicit `as String?` casts on Supabase metadata).

## Rationale

An abstract `AuthRepository` returning domain types (`AuthStatus` / `AppUser`)
keeps the domain pure like `ScoringService`, makes the feature fakeable, and
confines version-sensitive plugin API churn to one file. `AuthStatus` is a
`sealed` hierarchy so the UI switches exhaustively with no default branch. The
signed-in truth flows through the stream because `signInWithOAuth`'s
`Future<bool>` only reports that the OAuth URL launched. A separate
`AuthController` (`Notifier<AsyncValue<void>>`) holds only per-action
loading/error state, keeping authoritative state on the stream.
`authRepositoryProvider`'s default body throws, so a forgotten override fails
loudly in tests instead of hitting the network; production overrides it once in
`main()`.

## Design

```
lib/features/auth/
  domain/
    app_user.dart        AppUser value entity (==/hashCode), pure Dart
    auth_status.dart     sealed AuthStatus { SignedOut, SignedIn(AppUser) }
    auth_repository.dart  abstract interface AuthRepository
  data/
    supabase_auth_repository.dart   the ONLY plugin-importing file
  presentation/
    auth_providers.dart   authRepositoryProvider (throws by default),
                          authStateChangesProvider (StreamProvider, seeded),
                          AuthController (signInWithGoogle/signOut via guard)
    auth_gate.dart        switch over AuthStatus -> sign-in vs signed-in content
    sign_in_screen.dart   keyed Google button
    sign_out_button.dart  AppBar action calling signOut()
lib/config/app_config.dart   SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY (env)
lib/app.dart                 TreffpunktApp: MaterialApp + AuthGate
lib/bootstrap.dart           runTreffpunkt(overrides) -> runApp(ProviderScope)
lib/main.dart                Supabase.initialize then runTreffpunkt(real repo)
```

`AuthRepository.authStateChanges()` yields `currentStatus` first, then maps the
Supabase stream, so an authenticated user sees no sign-in flash (req 7). The fake
mirrors this. `main()` is the only place the real `SupabaseAuthRepository` and
`Supabase.initialize` exist; tests and the integration harness boot through
`runTreffpunkt` with a fake override.

## Verification

### Unit tests
- `auth_state_test` (ProviderContainer, fake override): starts SignedOut;
  `signInWithGoogle` → SignedIn; `signOut` → SignedOut; `currentStatus` seeds the
  initial value (no flash when seeded SignedIn).
- `auth_controller_test`: `signInWithGoogle` delegates (call count) and ends
  `AsyncData`; a forced failure surfaces `AsyncError` and status stays
  SignedOut; an in-flight delay shows `AsyncLoading`; `signOut` delegates.

### Widget tests
- Signed-out shows the Google button and no app content.
- Signed-in shows app content and no button.
- Tapping the button then emitting SignedIn swaps to app content (gate reacts to
  the stream).
- In-flight shows a spinner; a forced failure shows an error and the button is
  tappable again.

### System tests (headless, fake-backed)
- The full app boots on the sign-in screen; driving the fake
  SignedOut → SignedIn → SignedOut walks sign-in → content → sign-in.
- The existing scoring system test boots signed-in (fake) and still scores 10.9.

### Manual (once the user adds credentials)
- Web (Chrome): real Google account completes the redirect and lands on content.
- Android: native `google_sign_in` + `signInWithIdToken` with `serverClientId` =
  WEB client ID; SHA-1/256 (debug + release) registered; Skip Nonce Check on.
- Session persistence: reopen → still signed in; sign out → stays out.
- Cancel the Google dialog → error shown, no crash.

## Open questions
- Hosted vs local Supabase for first delivery (`skip_nonce_check` is local-only).
- Where signed-in content routes next (stay on the target screen vs a home /
  competitions surface) — next spec.
- A CI/architecture check forbidding `supabase` imports outside
  `lib/features/auth/data` to enforce the purity boundary.
