# Spec 0072 — Settings page (Innstillinger)

- **Status:** Accepted (increment 1 — consolidate existing settings). Editable
  brukernavn is a follow-up increment.
- **Related:** 0030 (theme mode), 0041 (training-image contribution), 0060 (push
  notifications), 0003 (sign-out) — this gathers their controls in one place.

## Context
The program picker's app bar carried four settings controls as loose icon
buttons — notifications, theme, training-image contribution and sign-out — on top
of the navigation and help icons. That is a lot of icons competing for the top
bar, and popup-menu icon buttons are an awkward home for on/off preferences. Give
the app one **Innstillinger** page and put those four behind a single gear.

## Requirements
1. A **gear** action on the program picker opens an **Innstillinger** page; the
   four settings buttons leave the app bar.
2. The page gathers, using the **existing** providers (behaviour unchanged):
   - **Konto**: the signed-in e-post (read-only) and **Logg ut**.
   - **Utseende**: theme — Følg systemet / Lyst / Mørkt.
   - **Varsler**: push notifications on/off, with the same subscribe/permission
     feedback; when push cannot work (no Push API, or no VAPID key) an explanatory
     disabled row instead of a dead control.
   - **Personvern**: bidra med treningsbilder on/off.
3. The **navigation** icons (Konkurranser / Mine økter / Forum / Brukerveiledning)
   stay in the app bar — they are destinations, not settings.
4. The **sign-in screen** keeps its own theme toggle (settings are unreachable
   before signing in).

## Rationale
**One page, existing providers.** The controls are just a different presentation
of `themeModeProvider`, `notificationsControllerProvider`,
`contributionConsentProvider` and `authControllerProvider`; the page renders them
as list rows (radio + switches + a tile) instead of app-bar popups, so no logic
moves or changes. The three now-unused app-bar widgets
(`NotificationToggleButton`, `ContributionToggleButton`, `SignOutButton`) are
removed; `ThemeModeButton` stays because the pre-sign-in screen still uses it.

**A gear, not a drawer.** The app navigates with `MaterialPageRoute` and full
screens (no router, no drawer); a settings screen pushed from a gear matches that
and the existing `HelpScreen`/`MySessionsScreen` shell.

## Design
- `lib/features/settings/presentation/settings_screen.dart`:
  - `SettingsButton` — the gear (`settingsButtonKey`) that pushes `SettingsScreen`.
  - `SettingsScreen` — `Scaffold`/`AppBar` 'Innstillinger', `ConstrainedBox(700)`,
    a `ListView` of four sections: account (email + `settingsSignOutKey`),
    appearance (`RadioGroup<ThemeMode>` with `settingsThemeOption*Key`),
    notifications (`settingsNotificationsKey` switch, gated by
    `webPushProvider`/`vapidPublicKeyProvider`), contribution
    (`settingsContributionKey` switch).
- `lib/app.dart`: the signed-in `ProgramPickerScreen(actions: [SettingsButton()])`.
- Removed: `notification_toggle_button.dart`, `contribution_toggle_button.dart`,
  `sign_out_button.dart` and their tests.

## Verification
- **Widget** (`settings_screen_test.dart`): the four sections + account e-post
  render; picking Mørkt writes `themeModeProvider`; the notifications switch
  subscribes and confirms; an unsupported push shows the disabled row; the
  contribution switch flips consent; Logg ut calls the auth repository.
- Full suite, analyze, format, REUSE, docs build green.

## Out of scope / next
- **Editable brukernavn** (display name) under Konto, and requiring one before
  posting — the follow-up increment (email-OTP users currently have no name).
