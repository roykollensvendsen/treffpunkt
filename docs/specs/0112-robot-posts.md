# Spec 0112 — Robot posts wear a robot identity

- **Status:** Accepted
- **Related:** specs 0054 (forum), 0063/0064 (reply bubbles); the
  forum-as-backlog workflow (the agent's clarifying questions)

## Context

The owner's automation asks clarifying questions on forum threads when a
reported task lacks the information to implement it safely. Those posts
are written from the owner's account with a «Robot: » body prefix — an
established convention in the threads — but the UI showed them under the
owner's own name, so readers could not tell the robot's questions from
his words. The owner asked for a robot icon.

## Rationale

The prefix already carries the signal in the data, so the UI can derive
the identity with no schema change: a reply whose body starts with
«Robot: » renders with a robot icon and the name «Robot», and the prefix
itself is hidden (the icon now says it). Such a post reads as the robot
for *everyone* — the account owner included — so it never takes the
"mine" bubble styling; the human's own words remain visually his.

## Requirements

1. A reply whose body starts with `Robot: ` shows a robot byline (the
   `smart_toy` icon + «Robot») instead of the author's name, and the
   body without the prefix.
2. Robot replies never take the "mine" alignment/colour, regardless of
   viewer.
3. Other replies are unchanged; copying a robot reply copies the full
   original text.

## Verification

- `forum_screen_test`: a `Robot: `-prefixed reply authored by the
  signed-in user renders the robot byline and icon, hides the prefix,
  and sits left-aligned like any other participant's reply.
- Existing forum suites unchanged.
