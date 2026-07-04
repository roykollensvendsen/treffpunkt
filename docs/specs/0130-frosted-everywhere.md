# Spec 0130 — Frostede kanter overalt

- **Status:** Accepted
- **Related:** spec 0129 (the frosted pieces and the first surfaces);
  owner follow-up in-session 2026-07-04 («frosset glass kan vel
  videreføres mange andre steder?»)

## Context

Spec 0129 frosted the main surfaces; the inner screens (thread, chat,
detail, setup, settings, notifications, felt …) kept opaque bars,
which now looked inconsistent next to the frosted ones.

## Rationale

Every remaining `AppBar` is a drop-in swap to `FrostedAppBar` (they
all use only title/actions/leading), giving one consistent edge
treatment app-wide. The screens whose body is a plain root list —
Varsler, Innstillinger, felt-løypa and Rekorder — additionally get
the full under-bar scrolling (`extendBodyBehindAppBar` +
`frostedScrollPadding` through a body-level `Builder`). Screens with
fixed headers, composers or forms keep their normal safe areas under
a frosted bar — translucency without underlap is still consistent.
The full-screen photo viewer deliberately keeps its dark chrome.

## Requirements

1. Every screen's app bar is a `FrostedAppBar` (photo viewer
   excepted).
2. Varsler, Innstillinger, felt-løypa and Rekorder scroll under their
   bars.
3. No behavioural change: every bar keeps its keys, actions and
   semantics.

## Verification

- The full suite passes unchanged apart from the spec-0129 shell
  assertions — every screen's interactions (dismiss, navigate, edit)
  exercise the converted bars.
- `grep` shows no `appBar: AppBar(` left outside the photo viewer.
