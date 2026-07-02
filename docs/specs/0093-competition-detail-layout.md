# Spec 0093 — Competition detail: results first, invites on their own page

- **Status:** Accepted
- **Related:** spec 0012 (competitions), 0032 (invite a registered shooter),
  0034 (delete), 0048 (join link), 0049 (archive), 0051 (chat)

## Context

For the owner, the competition detail page leads with the invite machinery:
the join-link section (three buttons) and the registered-shooter picker —
a list of **every** registered shooter — push the scoreboard and the
participants far below the fold, and the page gets worse as the user base
grows. The domain owner asks for the interesting content first: *"Det mest
interessante er vel scoreboard og deltakere?"*

## Requirements

1. The detail page shows, in order: the competition's subtitle, one compact
   **action row** — *Skyt nå* (participants), *Chat*, *Inviter* (owner only)
   — then **Resultater** and **Deltakere**. No invite section inline.
2. **Inviter** opens a dedicated invite page carrying both mechanisms
   unchanged: *Inviter med lenke* (Del lenke / Kopier lenke / Lag ny lenke,
   specs 0048) and *Inviter en registrert skytter* (spec 0032 — the same
   three tile states: Inviter / Invitert / Deltar).
3. *Slett konkurranse* (owner, spec 0034) and *Arkiver/Gjenopprett*
   (everyone, spec 0049) move to an app-bar **overflow menu (⋮)** on the
   detail page, keeping their confirmation/behaviour.
4. A non-owner sees no *Inviter* action and no *Slett* menu item; the
   archive item is available to everyone.

## Rationale

A dedicated page (rather than a bottom sheet or collapsibles) scales with
the shooter list, gives room for a future search field, and matches the
app's push-navigation idiom (spec 0084's category pages). Destructive and
rare actions belong in the overflow menu — the same pattern as the session
cards' delete (spec 0033) — not as full-width buttons amid content.

## Design

- `CompetitionInviteScreen` (new file): owns the join-link actions and the
  shooter picker (state `_invitingShooterId` / `_invitedShooterIds` moves
  with it), with the existing keys (`shareInviteKey`, `copyInviteLinkKey`,
  `regenerateLinkKey`, `shooterPickerKey`, tile keys).
- `CompetitionDetailScreen`: action row + Resultater + Deltakere; app-bar
  `PopupMenuButton` (key `competitionMenuKey`) with Arkiver/Gjenopprett and
  (owner) Slett — the existing `toggleArchiveButtonKey` /
  `deleteCompetitionButtonKey` move onto the menu items.
- New key `inviteCompetitionKey` for the Inviter action.

## Verification

### System tests (`competitions_screen_test`)
- The detail page shows Resultater before Deltakere and carries no inline
  invite controls; the owner's *Inviter* action opens the invite page.
- The join-link share/copy/regenerate flows and every shooter-picker state
  behave as before **on the invite page** (the existing spec-0032/0048
  tests, re-pointed).
- Delete and archive run from the overflow menu with their confirmations;
  a non-owner's menu has no Slett and the page no Inviter.

## Open questions
- None.
