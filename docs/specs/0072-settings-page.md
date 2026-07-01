# Spec 0072 — Settings page (Innstillinger) & brukernavn

- **Status:** Accepted (increment 1 — consolidate existing settings; increment 2
  — editable brukernavn + require it before posting).
- **Related:** 0030 (theme mode), 0041 (training-image contribution), 0060 (push
  notifications), 0003 (sign-out), 0010 (profiles) — this gathers their controls
  in one place and adds the account's display name.

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
   - **Konto**: the signed-in e-post (read-only) and **Logg ut** (which returns
     to the sign-in screen — the `AuthGate` drops any pushed screens on sign-out).
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

## Increment 2 — Brukernavn (display name)

Email-OTP users have no `full_name` in auth metadata, so their `profiles`
`display_name` is null and their chat/forum messages showed **"Ukjent"**. Add an
editable **brukernavn** and **require one before posting**.

- **Requirements.** Under **Konto**, a **Brukernavn** row shows the current name
  (or "Ikke satt") and opens an editor to change it. On sign-in a **default**
  name is set so no one shows as "Ukjent": keep a name the user already chose;
  otherwise the identity provider's name (Google); otherwise the **e-post local
  part** (before `@`). The name may be a **pseudonym** — it need not be the real
  name — so anonymity is possible. A rename shows **retroactively** on existing
  messages (names are joined live, spec 0010). Posting still falls back to a
  "Velg brukernavn" prompt if — unusually — no name is set at all (e.g. the
  profile sync has not yet run).
- **Design.** `CompetitionRepository.fetchProfile(id)` reads the own profile;
  `currentProfileProvider` / `displayNameProvider` expose it;
  `display_name.dart` holds `saveDisplayName` (reuses `upsertOwnProfile`),
  `ensureDisplayName` (the fallback gate) and the editor dialog
  (`displayNameFieldKey` / `displayNameSaveKey`). `ProfileSyncNotifier` now reads
  the existing profile first and **only fills a name when there is none**
  (keep-chosen → provider name → `emailLocalPart`), so it never overwrites a
  chosen brukernavn on a later sign-in. The chat `_send`/image-send and the forum
  reply/new-thread submit call `ensureDisplayName` first. **No migration** — the
  profiles table already allows an owner to update their own row (spec 0010).

## Verification
- **Widget** (`settings_screen_test.dart`): the four sections + account e-post
  render; picking Mørkt writes `themeModeProvider`; the notifications switch
  subscribes and confirms; an unsupported push shows the disabled row; the
  contribution switch flips consent; Logg ut calls the auth repository; editing
  the brukernavn saves it and shows it.
- **Widget/repo** (chat, forum, competition repo): posting with no name shows the
  prompt and blocks until one is chosen, then posts under it; `fetchProfile`
  returns the upserted profile; a rename shows on an existing message.
- Full suite, analyze, format, REUSE, docs build green.
