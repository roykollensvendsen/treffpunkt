# Spec 0050 — In-app user manual

- **Status:** Accepted
- **Related:** spec 0026 (my sessions), the `docs/user/` guide, ADR-0003
  (Riverpod seams)

## Context
The user guide lives in `docs/user/` and is published only as part of the
mkdocs site, which is not hosted anywhere users can reach. Shooters had no way
to read it from the app. We want the manual **inside the app**, working offline
(the app is offline-first — you read it on the firing line with no signal),
without maintaining a second copy of the text.

## Requirements
1. A **Brukerveiledning** (user manual) is reachable from the app: a help
   action in the program picker's top bar opens it.
2. It lists the manual's pages and opens each one **rendered** (headings, lists,
   bold, links), reading the **same `docs/user/*.md` files** the published guide
   uses — one source of truth, no duplicated prose.
3. It works **offline**: the pages are bundled with the app, not fetched.
4. A link between manual pages opens the linked page **inside** the manual; a
   link the manual does not contain (a dev-doc or external reference) does not
   break — it shows a short notice that the link is only in the web version.
5. The set of pages offered in the app stays **in sync** with `docs/user/`: a
   test fails if a user-guide page is added without being listed in the app (and
   vice versa), so the "document all functionality" rule cannot silently drift.

## Rationale
**Bundle the Markdown, render in-app — don't link out.** The mkdocs site is not
hosted, so linking out would need new hosting and a network connection, and
would leave the app. Bundling `docs/user/` as Flutter assets and rendering them
with `flutter_markdown` keeps the **same files** as the single source, works
offline, and stays in the app. The only added artefact is a small ordered list
of (file, title) for the table of contents — guarded by a sync test so it cannot
fall behind the directory.

**A loader seam for testability.** The page screen reads its Markdown through a
`manualLoaderProvider` (default `rootBundle.loadString`), overridden in tests
with canned text, so widget tests do not depend on real asset bundling.

## Design
- `lib/features/help/domain/manual.dart` (pure Dart): `ManualPage(file, title)`,
  the ordered `manualPages` list (mirrors the mkdocs nav, minus the `index.md`
  overview), and `manualPageForLink(href)` which resolves a Markdown link href
  to a `ManualPage` or `null`.
- `lib/features/help/presentation/help_providers.dart`: `ManualLoader` typedef
  and `manualLoaderProvider` (default loads `docs/user/<file>` from the bundle).
- `lib/features/help/presentation/help_screen.dart`: `HelpScreen` (the contents
  list, each row keyed by `manualPageTileKey(file)`) and `ManualPageScreen`
  (loads + renders one page with `Markdown`, `onTapLink` navigating to a bundled
  page or showing the "web only" notice). A leading HTML licence comment is
  stripped before rendering.
- `docs/user/` is declared as an asset directory in `pubspec.yaml`; the help
  action (`helpButtonKey`, a `?` icon) sits in the program picker's app bar.

## Verification
### Unit tests
- `manualPages` is non-empty; every entry has a non-empty title and a `.md`
  file; `manualPageForLink` resolves a known page name (with/without an anchor)
  and returns `null` for an unknown or external href.
- **Sync guard:** the set of `manualPages` files equals the `.md` files in
  `docs/user/` (excluding `index.md`).

### System tests
- The program picker shows the help action; tapping it opens `HelpScreen` listing
  every manual title.
- Tapping a page opens it and renders the (injected) Markdown content.
- The help screen's loader seam is overridden, so the test needs no real assets.

## Open questions
- A search box across pages could come later; the list is small enough for now.
