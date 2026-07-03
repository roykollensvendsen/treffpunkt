# Spec 0119 — The robot is called Robot Hood

- **Status:** Accepted
- **Related:** spec 0112 (robot posts wear a robot identity); named by
  the owner in-session 2026-07-03

## Context

Spec 0112 gave the automation's forum posts a robot identity: the
`Robot: ` body prefix renders as a robot icon with the byline «Robot».
The owners wanted a friendlier name and chose **Robot Hood** — after
history's most famous marksman, fitting for an app about hitting the
mark.

## Rationale

Only the *displayed* name changes. The `Robot: ` body prefix is the
wire convention every existing post already carries and every post
template writes, so it stays — renaming the wire format would strand
the history. One string in the byline, one line in the user guide.

## Requirements

1. Posts with the `Robot: ` prefix show the byline **Robot Hood**
   (icon unchanged, prefix still stripped from the shown body).
2. The wire prefix `Robot: ` is unchanged.

## Verification

- The spec-0112 widget test asserts the byline reads «Robot Hood» for
  a prefixed post, with the icon and without the prefix.
