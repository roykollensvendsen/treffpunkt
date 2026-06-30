# Spec 0061 — Sign in with a one-time email code

- **Status:** Accepted
- **Related:** spec 0003 (Google sign-in), spec 0042 (blocked-browser notice).

## Context
Google sign-in uses an OAuth **redirect**, which fails in some contexts — most
notably on **iOS**, where an in-app/standalone webview is blocked and a
misconfigured redirect can land on a 404 (spec 0042). We add a **passwordless
fallback** that uses **no redirect at all**: the user gets a **one-time code** by
email and types it in. It works in any browser, so it is the reliable path for
iPhone users.

## Requirements
1. From the sign-in screen, a user can choose **email sign-in**: enter their
   email, request a code, then enter the **code** from their inbox to sign in.
2. It is offered **alongside** Google (an "eller" divider), not instead of it.
3. A first-time email is **registered** on successful verification (sign-up and
   sign-in in one), consistent with Google.
4. Clear inline feedback: an invalid email is rejected before sending; a failed
   send and a wrong/expired code each show a message; nothing blocks retrying.
5. The blocked-browser notice (spec 0042) points the user to this email option.

## Rationale
**The code flow avoids the redirect entirely.** `signInWithOtp(email)` emails the
user; `verifyOTP(email, token, type: email)` checks the typed 6-digit code — no
`redirectTo`, no callback round-trip, so none of the OAuth/webview failure modes
apply. (A magic *link* would re-introduce a redirect, so we use the **code**.)

**It reuses the existing auth seam.** Two methods on `AuthRepository`
(`sendEmailOtp`, `verifyEmailOtp`) — the Supabase implementation is two GoTrue
calls; the fake drives the widget tests. Success arrives through the same
`authStateChanges` stream, so the `AuthGate` swaps in the app exactly as for
Google. The email flow keeps **local** UI state and shows its own inline errors,
separate from the shared Google-button error.

**Server-side prerequisites (documented, not code).** Email auth must be enabled,
the Magic-Link email template must include the code (`{{ .Token }}`) for the
no-redirect flow, and a custom **SMTP** is recommended because Supabase's built-in
email is heavily rate-limited (see `docs/dev/deploy.md`).

## Design
- `AuthRepository.sendEmailOtp(email)` / `verifyEmailOtp(email, code)`;
  Supabase impl via `signInWithOtp` / `verifyOTP(OtpType.email)`; fake accepts a
  known code and registers the email on verify.
- `SignInScreen`: an `_EmailOtpSignIn` two-step widget (email → code) under an
  "eller" divider; the screen is now scrollable so the extra content (and the
  blocked-browser notice) never overflows a short viewport.

## Verification
### Widget tests (fake repository)
- Entering an email and requesting a code calls the repository and reveals the
  code step; entering the correct code signs in.
- A wrong code shows an error and stays signed out.
- An invalid email is rejected before any send.
- Existing Google + blocked-browser tests still pass (now scrollable).

### Manual (after the dashboard setup)
- On an iPhone: enter email, receive the code, type it, and reach the app —
  without using Google.

## Open questions
- A "resend code" affordance with a cooldown.
- Remembering the last-used method per device.
