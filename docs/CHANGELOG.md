# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Shoot the NorgesFelt course**: from the course preview, tap **Skyt løypa** to
  record a round — choose your group (6 shots/hold for group 1, 5 for groups
  2–3), then place each shot on the hold picture where it hit. The app resolves
  which figure and inner zone each shot landed in and scores it NorgesFelt-style
  (1 point per hit, 1 per distinct figure hit, 1 per inner-zone hit), with a live
  total and an end scorecard (spec 0080).
- **Resume a felt round**: an in-progress felt round is saved as you place shots
  and survives an app restart; the course page shows a **Fortsett felt-økt** card
  to pick it up exactly where you left off, or discard it (spec 0081).
- **Felt rounds in "Mine økter"**: finishing a felt round saves it (locally) and
  it now shows in **Mine økter** alongside your ring sessions, by date, with its
  total points; tapping it opens the felt scorecard (spec 0082).
- **Felt rounds sync to your account**: finished felt rounds now upload to your
  Supabase account (owner-only) and show in "Mine økter" across devices — sync is
  best-effort and offline-tolerant, so a round is always kept locally and uploads
  when you're signed in (spec 0083). Needs the `felt_sessions` table migration
  applied to the hosted project.

### Added
- **Varsler — a notification center**: the program picker's top bar has a
  **bell** with a live unread badge. It collects competition invitations,
  new chat messages in your competitions and new replies in forum threads
  you take part in; tapping a notification jumps straight to the
  invitation, chat or thread and marks it read (or **Marker alle som
  lest**). Read status follows your account. Needs the `notifications`
  table migration applied to the hosted project (spec 0094).
- **NorgesFelt rounds get time, place and weapon**: "Skyt løypa" now starts
  with the same setup step as the other programs — date and time, place
  (typed or from **Bruk min posisjon**) and your weapon — before the group
  picker. The details follow the round through save/resume and sync, show on
  the round's card and scorecard in "Mine økter", and the chosen date is
  what orders the round in lists and statistics (spec 0092).
- **Statistikk — see if you are improving**: "Mine økter" has a new chart
  button that opens per-exercise progress curves. Pick an øvelse and see your
  **poengsum** and **innertreff** per completed session as two coloured
  curves in one chart with a legend — no time axis, the x-axis is your
  sessions in order. Tap or drag to read a specific session's numbers; both
  ring programs and the NorgesFelt course are included, local and synced
  sessions alike (spec 0090).
- **Delete a felt round from "Mine økter"**: a NorgesFelt round's card now has
  the same menu (⋮) → **Slett** → confirmation as the ring sessions; deleting
  removes the round from your account (when synced) and the device (spec
  0089).

### Added
- **Zoom and pan the felt hold pictures**: the NorgesFelt recorder now
  zooms (1–6×) and pans exactly like the ring targets — pinch,
  two-finger trackpad scroll or the on-picture ＋/−/reset buttons — so
  a shot can be placed precisely on the small figures. Placement is
  unaffected by the zoom (spec 0125).

### Changed
- **The decimal is the headline in decimal mode**: on a decimal-mode
  session the big number on the series-sum and grand-total cards is
  now the decimal sum, and the running line and scorecard rows lead
  with it («Økt så langt: 109,0 (100)») — the integer drops to a
  «Heltall N» line. Records, statistics and scoreboards still count
  whole points, and sessions without decimal mode look exactly as
  before (spec 0124, forum request).

### Added
- **Er Robot Hood her?**: the forum now shows whether the owner's
  automation is listening right now — a green dot and «Robot Hood er
  på vakt», or an honest grey «ikke her nå — svar kommer når roboten
  våkner» when its heartbeat is older than five minutes (machine off,
  robot asleep). Needs the `robot_presence` migration applied to the
  hosted project (spec 0122).

### Fixed
- **Digits, not stripes, on the luftduell face**: the domain expert
  checked the physical Sprintluft sheet — it carries ordinary values
  5–9 on both axes and no white sighting lines (the rulebook's own
  figure agrees; its text does not). The face now prints the digits
  horizontally too and the stripes are gone; the 25 m duel face keeps
  its lines (spec 0123, forum follow-up).

### Fixed
- **The luftduell face wears its own black**: Sprintluft/Storluft's
  10 m luftduellskive was drawn all black like the 25 m duel face —
  indistinguishable on screen. Per the rulebook figure
  (§ 5.1.18.1.2) its black covers only the 8-zone (⌀ 76 mm): 8 and 9
  now sit white on black, 5–7 on white paper, and the white sighting
  lines run from the face's edge in through the rings, notching the
  black. The 25 m duel face is unchanged (spec 0121, forum request).

### Added
- **Tag people with @**: type **@** in a forum reply, a new thread or a
  competition chat message and pick a name — the tag renders as a
  highlighted **@Navn** and the tagged person gets a **Varsler**
  notification that takes them straight there (and they are not
  notified twice for the same message). In forum threads you can also
  tag **@Robot Hood** to have the robot read the thread and answer
  (spec 0120, forum request). Needs the `mentions` migration applied
  to the hosted project.

### Changed
- **The robot has a name — Robot Hood**: the automation's forum posts
  now carry the byline «Robot Hood» (after history's most famous
  marksman) instead of the plain «Robot»; the icon and behaviour are
  unchanged (spec 0119).

### Fixed
- **Local time everywhere**: dates on «Mine økter» could show the wrong
  day because uploads dropped the timezone and the stored moment was
  read as UTC («Zulu tid»). Sessions now upload the true instant, every
  timestamp entering the app is converted to the phone's local time,
  and the build stamp on the front page shows the build minute as local
  `dd.MM.yyyy HH:mm`. A one-time migration repairs the already-stored
  session times (spec 0118, forum request). Needs the
  `captured_at_local_repair` migration applied to the hosted project.

### Added
- **«Jobber med» — a thread status for work in progress**: forum threads
  can now show an amber badge between «Planlagt» and «Ferdig», so the
  list tells you a planned task is being worked on. The robot sets it
  when it starts on a thread and moves it to «Ferdig» when the fix is
  deployed (spec 0117). Needs the `forum_thread_in_progress` migration
  applied to the hosted project.

### Changed
- **One «Fortsett felt-økt» card**: resuming an in-progress felt round
  now lives on the front page alone — the duplicate card on the course
  page is gone, and the front-page card gains the trash button to
  discard the saved round (with the usual confirmation) that used to
  sit only on the course page (spec 0116, forum request).

### Changed
- **Adjust the decimals of earlier shots**: in decimal mode every shot
  in the current series keeps its tenth dropdown, not just the last one
  — notice a mistyped reading a few shots later and correct it on the
  spot. Picking a value moves that shot's marker to match, exactly as
  on the last shot; sealed series stay read-only (spec 0115, forum
  request).

### Added
- **Decimals on every ring face**: the «Desimalpoeng» toggle is now
  offered on all ring programs — Sprintluft, Storluft, Hurtigpistol,
  Silhuettpistol and NAIS included — and Fin-/Grovpistol sums decimals
  across both its faces. Under the hood the tenth now subdivides the
  shot's own scoring band, which also fixes a subtle mismatch the old
  model had near band edges on the 25 m faces (spec 0114, forum
  request).

### Added
- **Ring values on the targets**: the drawn faces now print the zone
  values exactly as the official gtr-2026 sheets do — 1–8 on the
  luftpistol face, 1–9 on 25 m presisjon/50 m (both along both axes),
  5–9 vertically on the duell and luftduell faces, which also get their
  white sighting lines (125 × 5 mm and 42,5 × 3 mm). Zones above stay
  unnumbered, digits are sheet-true in size and skipped on tiny review
  targets where they would smudge (spec 0113, forum request; sourced
  from gtr-2026 and nasjonalt regelverk § 5.1.18 on skyting.no).

### Added
- **Robot posts wear a robot identity**: when the owner's automation
  asks a clarifying question on a forum thread (a reply starting with
  «Robot: »), the bubble now shows a robot icon and the name «Robot»
  instead of the owner's name — so the robot's questions are never
  mistaken for his words (spec 0112).

### Added
- **Decimals on the 25/50 m precision programs**: the «Desimalpoeng»
  toggle is now offered on 25 m Standard Pistol, 25 m Finpistol,
  25 m Grovpistol and 50 m Fripistol too. On Fin-/Grovpistol the
  precision series get the full decimal treatment while the duel
  series honestly stay in whole points — no partial decimal sums are
  ever shown (spec 0111, forum request).

### Changed
- **Picking a decimal moves the shot**: in decimal mode, choosing e.g.
  9,7 now slides the marker in/out from the centre so its position *is*
  the picked value — a picked 10,9 lands inside the innertier ring, and
  dragging a shot afterwards re-derives the decimal from where it lands
  (spec 0110, user request).

### Added
- **Remove notifications**: swipe a varsel away to delete it, or use the
  new **Fjern alle** action (with a confirmation) to clear the list —
  deletions follow your account. Needs the notifications-delete
  migration applied to the hosted project (spec 0109, user report).

### Fixed
- **«Skyt igjen» no longer needs a refresh**: the card follows your
  latest session the moment it completes — it now watches the live
  upload queue, and coming back to Hjem (or switching to the tab)
  refreshes the history it derives from, felt rounds included
  (spec 0108, user report).
- **The felt course preview tells the truth about inner zones**: the
  header no longer claims «innertreff på alle figurer» — each hold card
  now derives its coverage from the measured art, and hold 5 says
  «Innertreff på 1 av 2 figurer (ikke Trekant stor)», matching the
  official sheet. Scoring already agreed; only the text was wrong
  (spec 0104, forum report).
- **The inner-ten ring is drawn on the target**: the faces that have an
  inner ten (luftpistol 5 mm, 25 m presisjon 25 mm, duell 50 mm) now show
  its ring on the drawn target, white on the black like the real sheets —
  so you can see what the ringed-X count refers to while placing shots
  (spec 0103, forum request).

### Added
- **Desimalpoeng på luftskivene**: turn on «Desimalpoeng (elektronisk
  skive)» in the setup step of the luft programs and every shot gets a
  decimal value, Megalink-style — plot the shot as usual and the last
  shot's row shows a dropdown (9,0–9,9 in the plotted ring), preselected
  from where you tapped, so transferring the readings is one optional
  tap per shot. Decimal sums show beside the ordinary points on the
  shooting screen and every scorecard; records, statistics and
  scoreboards keep counting whole points. The choice is remembered, and
  the tenths survive save/resume and sync (spec 0107, forum idea).

### Added
- **Sikkerhetskopi**: under **Innstillinger → Sikkerhetskopi** you can
  export everything — ring sessions, felt rounds, weapons, record
  baselines and the default place — as one JSON file through the share
  sheet, and restore from such a file on any device. Restoring is
  additive: nothing you already have is touched, and restored sessions
  also upload to your account on the next sync (spec 0106, forum
  request).

### Added
- **Felt rounds replay on the targets**: open a saved NorgesFelt round
  (the end-of-round scorecard or "Mine økter") and every hold now shows
  its picture with the shots marked where they landed — green for inner
  hits, amber for hits, red for misses, exactly as while recording. The
  positions were already stored; synced rounds show them too (spec 0105,
  forum idea).

### Added
- **Standard sted**: set the range you usually shoot at under
  **Innstillinger → Skyting**, and the setup step before every session
  (felt too) starts with the place pre-filled — still editable, and **Bruk
  min posisjon** works as before (spec 0102).
- **Personlige rekorder with starting values**: a new **Rekorder** page
  (from Innstillinger → Skyting, or the trophy on Statistikk) lists every
  exercise with your current record. Enter the record you had *before* the
  app as a starting value — «Ny pers!» then only celebrates when you beat
  the best of that value and your recorded sessions, and the shown record
  updates by itself when you do (spec 0102).
- **«Ny pers!» on the scorecard**: finish a session that beats your best
  earlier result on the same exercise (points, with inner hits as the
  tiebreak) and the scorecard celebrates it with a signal-red «Ny pers!»
  field — for the ring programs and the NorgesFelt course (per group)
  alike. Old sessions in "Mine økter" are never re-celebrated (spec 0101).
- **Logo mark and category pictograms**: the home title wears the
  Treffpunkt mark (the target with a red bull), and the four category cards
  each carry a small pictogram — fine rings for Luft, a heavy bull for
  Fin/Grov, the silhouette for MIL and felt's figure pair (spec 0101).
- **A look that says shooting**: the app reseeds from a deep blue-graphite
  with the **signal red of a hit** reserved for the moments that matter —
  the newest shot on the target now pops in red with its halo while older
  shots recede (the convention of the range monitors), a drawn **target
  icon** replaces the map icons on every «skyt»-button, score digits are
  tabular so totals align, the target paper is slightly warm in dark mode,
  and the scoreboard's top three wear gold, silver and bronze (spec 0100).
- **The felt recorder remembers your group**: pick Gruppe 1 or 2 once and
  the next round starts straight on hold 1; a group button in the top bar
  lets you change it until the first shot is placed (spec 0099).
- **Bottom navigation and a cleaner start page**: a bar at the bottom now
  takes you to **Hjem**, **Mine økter**, **Statistikk**, **Stevner**
  (konkurransene) and **Forum** — always visible, with labels. Hjem is all about shooting:
  a highlighted **Skyt igjen** card restarts your latest exercise in one
  tap, in-progress rounds show as **Fortsett økt** / **Fortsett felt-økt**
  cards, and the categories sit in a compact grid — **Felt** opens the
  course directly and **MIL** is marked «kommer senere».
  Brukerveiledningen moved to Innstillinger (spec 0097).
- **Angre and a real «Fullfør serie» button while shooting**: a bottom bar
  on the shooting screen carries **Angre** (removes the last shot) and a
  full-width **Fullfør serie (n/N)** button that always shows how far the
  series is — replacing the small icon in the top bar (spec 0098).

### Fixed
- **The highlighted weapon is the weapon that gets recorded**: on the next
  session of the day the previously chosen weapon looked selected in the
  setup step but silently fell off the session unless tapped again; the
  form now attaches what the picker highlights (spec 0095).

### Changed
- **Norwegian all the way through**: the shooting screen (Skudd, SERIESUM,
  ØKTSUM, «Økt fullført» …), the weapon picker («Legg til våpen» …) and
  sign-in («Logg på med Google») now speak Norwegian, and the date/time
  pickers follow (Norwegian month names and buttons). Dates show as
  dd.MM.yyyy everywhere, deleting a forum thread/post and discarding an
  in-progress round now ask first, empty screens share one friendly
  pattern, and a handful of colours/labels were aligned (spec 0096).
- **The competition page leads with the scoreboard**: the invite machinery no
  longer fills the top of the page. One compact action row — **Skyt nå**,
  **Chat** and (for the owner) **Inviter** — sits above **Resultater** and
  **Deltakere**; the **Inviter** button opens its own page with both invite
  ways (link and registered shooters), and **Arkiver**/**Slett** moved to the
  **⋮** menu in the top bar (spec 0093).
- **NorgesFelt: save the round with a button — never duplicates**: finishing
  a round now shows the scorecard without saving; tap **Lagre økt** to save
  it — exactly once, however much you walk back and forth (the round keeps
  one identity, and saving again replaces rather than duplicates). An
  unsaved finished round stays resumable from **Fortsett felt-økt**, so
  nothing is lost (spec 0091). Fixes finished rounds getting saved several
  times when navigating Fullfør → tilbake → Fullfør.
- **NorgesFelt: a hit on a stripe's dividing line counts**: a shot placed on
  the thin white line between two squares of a three-square stripe (Hold 2
  and 8) previously scored as a miss; it now counts as a hit on the stripe
  (not an innertreff — only the middle square is, spec 0087).
- **NorgesFelt: only Gruppe 1 and 2 are offered**: Gruppe 3 is not shot on
  the course (it is the class for heavier weapons), so the group picker no
  longer offers it; an already-saved gruppe-3 round still loads (spec 0088).
- **NorgesFelt: the total in a result box**: the felt scorecard now shows the
  round's total in the same filled, coloured result card as the ring
  scorecards — the big points number with the group label and the ringed-X
  inner count (spec 0089).
- **NorgesFelt: the three-square stripes score as one figure, middle square =
  innertreff**: on Hold 2 and Hold 8 the stripe figures printed as three
  squares in a row/column now score correctly — hitting two squares of the
  same stripe credits the figure once, and a hit in the **middle square
  counts as innertreff** (these figures have no ring). Drawing is unchanged
  (spec 0086).
- **NorgesFelt: innertreff is the tiebreaker, not points**: a felt round now
  scores **1 point per hit and 1 per figure hit** — inner-zone hits no longer
  add points (max is 80 for gruppe 1, as on the official course). The inner
  hits are counted separately as the tiebreaker (most inner wins on equal
  points) and shown next to the points as **· N Ⓧ**, the same ringed X the
  ring programs use for inner tens — on the recording screen, the scorecard
  and in "Mine økter". Already-saved rounds show the corrected totals
  automatically (spec 0085).
- **The program picker is grouped into categories**: the "Velg program" front
  page now shows four categories — **NSF Luft**, **NSF Fin/Grov**, **MIL** and
  **Felt** — instead of one long list of every program. Tap a category to see
  its programs: the luftpistol programs under NSF Luft, the 25 m / 50 m fin- og
  grovpistol programs under NSF Fin/Grov, and the NorgesFelt course under Felt.
  MIL is the home for the military programs, which are not seeded yet (spec
  0084).
- **Composed NorgesFelt holds**: each hold in the course preview is now drawn as
  **one picture matching the official target sheet** — the figures at their real
  relative size and position, white figures knocked out of coloured backing
  plates, the **black vertical lines between målgrupper**, and the inner-treff
  ring on every figure — instead of a strip of separate figures. The round
  **C-figures** are cut flat across the bottom. The geometry is reconstructed
  from the official images and measured for faithfulness (spec 0079).
- **More accurate NorgesFelt figures**: the field-course figures are now traced
  from the official high-resolution blink images, so the **1/6**, **bowling
  pin**, **sekskant**, **egg**, the small rounded **triangle** and the big
  **right-angled triangle** all match the real targets. The **C-figures** (C13 /
  C20 / C25) are drawn as a **truncated circle** — flat across the bottom — not a
  full circle (spec 0077). Each hold's figures are shown in the hold's real
  **colour** — black, green or red — as on the course (spec 0078).

### Added
- **"Bruk min posisjon" now fills a place name**: instead of raw coordinates, the
  place field is filled with the **name** of where you are (town/area), looked up
  from your location. If the name can't be resolved it falls back to the
  coordinates as before, and the coordinates are still saved (spec 0076).
- **GIF uploads, and a clear message for unsupported files**: you can now attach
  **GIF** images (as well as JPG/PNG) in chat and the forum, and they keep their
  animation. Files that aren't a supported image are refused with **"Filformatet
  støttes ikke. Bruk JPG, PNG eller GIF."** instead of being stored wrong (spec
  0075).
- **Tap a picture to view it full-screen**: pictures in chat and the forum now
  open **full-screen** when tapped, where you can **zoom** (pinch/scroll) and
  **pan** (drag) to see the details — with a close button to return (spec 0073).

### Fixed
- **Scroll the field-course figures with a mouse**: on the NorgesFelt-løype 2026
  preview you couldn't reach the figures past the edge of a hold in a desktop
  browser (no touch swipe). The strips now show a scrollbar and can be
  dragged with the mouse/trackpad — everywhere in the app (spec 0074).
- **Logg ut now returns you to the sign-in screen**: signing out from
  Innstillinger used to leave the settings page on top; it now drops any open
  screen and lands on the sign-in screen (spec 0072).
- **Deleted/edited chat messages now update live**: a deleted (or edited) message
  used to keep showing until you restarted the app — the live update was silently
  dropped for filtered subscriptions. Deletions and edits in a competition chat
  (and forum replies) now appear immediately for everyone (spec 0071).
- **Icons could appear blank after an update**: the web build shipped a per-build
  *subset* of the icon font at a fixed, non-cache-busted URL, so a returning
  browser kept its cached old subset and any newly added icon (e.g. the **Kopier
  tekst** copy symbol) rendered blank. The build now ships the full icon font,
  identical every deploy, so icons show immediately (spec 0027).

### Added
- **Settings page (Innstillinger)**: the theme, notifications, training-image and
  sign-out controls that used to crowd the top bar now live behind a single
  **gear** on one Innstillinger page — account (e-post + logg ut), utseende,
  varsler and personvern in one place (spec 0072).
- **Brukernavn (display name)**: set a display name under **Innstillinger →
  Konto** — it can be a **kallenavn**, so you stay anonymous while your messages
  still show a name. New sign-ins get a sensible **default** name (your Google
  name, or the part of your e-post before `@`) so no one shows as "Ukjent", and a
  chosen brukernavn is **kept** across sign-ins (it is no longer reset). Changing
  it updates your name on earlier messages too (spec 0072).
- **Edit your own chat message**: long-press your message in a competition chat
  and choose **Rediger** to fix a typo — the change shows live for everyone. Only
  the author can edit (the owner still moderates by deleting); spec 0070.
- **Copy message text**: long-press a chat message, a forum reply, or a forum
  thread's opening post and choose **Kopier tekst** to put its text on your
  clipboard — a short **Tekst kopiert** confirms (spec 0069).
- **Feltskyting** (field shooting): under **Feltskyting** in the program list you
  can now preview the **NorgesFelt 2026 course** — all 8 holds with their actual
  **figures** (hare, wolf head, ptarmigan, hexagons, triangles, circles …) drawn
  to real relative size, each with its inner zone. The figures are scalable
  vector drawings reconstructed from norgesfelt.no (spec 0068). Recording and
  scoring on the figures come next. The figures now look like the real targets —
  a **black silhouette on a white plate** — and each **inner zone** is ringed at
  the figure's centre of mass, so it sits on a triangle's lower third or an
  animal's body instead of the bounding-box centre.
- New program **25 m Silhuettpistol** (.22): 60 shots, 12 series of 5 across
  three timed stages (8 / 6 / 4 s). A series is recorded on a **bank of five
  silhouettes** — one shot at each, in firing order — and the scorecard reviews
  it the same way (spec 0067).
- Forum threads now have a **status** a moderator can set — **Åpen**,
  **Planlagt**, **Ferdig** or **Avvist** — shown as a small badge, so you can see
  which bugs/ideas are done or rejected (spec 0066).
- Chat messages and forum threads/replies now show a small **timestamp** of when
  they were posted — just the time today, the date earlier (spec 0065).
- Forum replies now look like the **chat**: your own replies sit on the **right**
  in an accent bubble, others' on the left with their name — so it's easy to see
  who said what (spec 0064).
- **Edit your own forum messages**: fix a typo in your own thread (the pencil in
  its top bar — title and text) or your own reply (long-press → **Rediger**).
  Only the author can edit; moderators still delete, not edit (spec 0063).
- **Paste an image** (Ctrl/Cmd+V) straight into a competition chat, a forum reply
  or the new-thread form — e.g. a screenshot — instead of picking a file. On the
  web; the picker button still works everywhere (spec 0062).
- **Sign in with a one-time email code** as an alternative to Google: enter your
  email, get a code in your inbox, and type it in — no Google, no redirect, so it
  works in browsers where Google sign-in is blocked (e.g. iPhone) (spec 0061).
- **Notifications** (Android/desktop): turn on the **bell** in the top bar to get
  a system notification for a new competition message or an invitation — even
  when the app is closed. Moderators also get one for a **new forum thread or
  reply** (a reported bug or idea), so feedback is not missed. iPhone is not
  covered yet (it would require installing the app in a way that breaks sign-in);
  a native app is the path there (spec 0060, ADR-0026).
- You can now **see who reacted**: hold (long-press) a reaction on a chat
  message, a forum thread or a forum reply to open a list of everyone who
  reacted with that emoji (spec 0059).
- The scorecard now shows **each series' target with your shots** marked. So
  when you open a saved session (in "Mine økter"), or finish one, you can see
  exactly where every shot landed — not just the numbers (spec 0058).
- Competitions can now have a **date**, and the competitions list has a
  **calendar** (the calendar button in the top bar) to filter by it: set an
  optional date when creating a competition, then tap a day to see that day's
  competitions. Days with a competition are marked (spec 0057).
- A **community forum** (the speech-bubble button in the top bar) where anyone
  signed in can report **bugs**, suggest **features/ideas** and discuss them.
  Start a categorised thread (Bug / Ønske / Generelt), reply, and filter by
  category — threads and replies update live. You can delete your own; a
  moderator can tidy up anyone's (spec 0054). You can also **react** with an
  emoji to a thread or reply — a quick way to "vote" 👍 on a bug or idea
  (spec 0055) — and **attach a picture** to a thread or reply (spec 0056).
- Each competition now has a **chat**. Open a competition and tap **Chat** to
  talk with the others in it — messages appear live for everyone, with the
  sender's name. Anyone who can see the competition can read it; participants can
  post. You can delete your own messages, and the owner can moderate (spec 0051).
  You can also **react** to a message with an emoji (tap the emoji button under
  it; tap a reaction again to take it back) — reactions update live (spec 0052).
  And you can **attach a picture** to the chat (the image button by the message
  box); chat images are private to the competition (spec 0053).
- The **user guide is now inside the app**. Tap the **?** button — in the top
  bar when signed in, or on the sign-in screen before you sign in — to open
  "Brukerveiledning". It is the same guide pages as the website, bundled so they
  work offline, with links between pages opening in place (spec 0050).
- You can now **archive** old competitions to tidy your list. Each competition
  has an archive button (on its card and inside its detail), and archived ones
  move into a collapsed "Arkiverte" section (tap to expand) you can restore
  from. Archiving only
  affects *your* view — it never deletes the competition or changes what other
  participants see — so it also works for competitions **created by someone
  else**, which you cannot delete (spec 0049).
- You can now see which build of the app you are running. A discreet line at the
  bottom of the sign-in screen and the program picker shows the build version —
  the deploy's short commit and build time (e.g. "build a1b2c3d4 ·
  2026-06-23T17:30Z"), or "build dev" for a local build. So after a deploy you
  can confirm at a glance that you are on the latest build instead of a stale
  cached page, and report the exact build when something looks wrong. The
  version is the same one the cache-bust query uses, so the screen and the
  loaded assets always agree (spec 0028).
- The empty "Mine økter" screen is now welcoming and useful: when you have no
  saved sessions yet it shows a friendly note ("Ingen lagrede økter ennå"), a
  hint ("Fullfør en økt for å se den her.") and a "Velg program" button that
  takes you straight back to pick a program — so a first-time shooter is told
  what to do next instead of facing a bare line of text.
- You can now look back at your saved sessions. A new "Mine økter" screen (open
  it from the history button in the top bar) lists every session you have
  recorded, newest first: the ones already saved to your account and the ones
  still waiting to upload, each marked "Ikke synkronisert" until it syncs. Each
  card shows the program, when and where you shot it, the score and the weapon,
  and tapping one opens its full scorecard — the same per-stage and per-series
  (skive) breakdown you saw when you finished it. A session whose program is no
  longer available shows a friendly "Kan ikke vise denne økta" instead of
  failing (spec 0026).
- Finished sessions are never lost, even offline or signed out. When you
  complete a session it now joins a durable upload queue saved on your device,
  and the queue empties itself by uploading whenever it can: the moment you
  finish, the next time you open the app, and right after you sign in. So a
  session shot with no signal — or before you have signed in — uploads itself
  automatically later instead of vanishing. Uploading stays quiet and
  best-effort (it never blocks finishing, never crashes on a dropped
  connection), and the same session is never uploaded twice (spec 0025).
- When you are signed in, finishing a session now quietly saves it to your
  account in the cloud, so your results survive reinstalling the app or switching
  devices. The save never blocks finishing, never crashes if the connection
  drops, and re-saving the same session never makes a duplicate (spec 0024).
- The session scorecard now lists every target face (skive) on its own line:
  under each stage you see each series' score (ring total over its maximum, and
  the inner-ten count when there is one), kept subordinate to the per-stage
  subtotal and the grand total — so you can read each face's result the way a
  paper scorecard does (spec 0023).
- The shot you just fired now stands out: while shooting a series the most
  recently placed shot is ringed with a coloured halo on the target (at the same
  size as the others), and its row in the shots list is highlighted, so you can
  instantly see where your latest shot landed. As you place each new shot the
  emphasis moves to it. A shot you are dragging keeps its blue "moving" look
  (spec 0020).
- The app now works with a screen reader (TalkBack / VoiceOver). The target
  announces itself and how to use it, the series and session totals are read
  aloud in words ("Serie-sum: 87 av 100, 3 indre tiere") instead of loose
  digits, each shot row says its number and ring, and the stage header, the
  seal-series button, the program tiles and the resume / discard actions all
  carry clear spoken labels in Norwegian.
- The app now makes proper use of a wide screen. On a desktop, tablet or
  browser window the content no longer stretches edge-to-edge: it is held to a
  comfortable reading width and centred. On a wide shooting screen the target
  and the shot list / score now sit side by side, so you can see your shots
  next to the face without scrolling. On a phone everything looks exactly as
  before — one tidy column.
- When location permission is turned off for good, the session-setup step now
  offers an "Åpne innstillinger" button that jumps straight to the app's
  location settings — the only place that permission can be switched back on.
  Every other case (a one-off "not now", location switched off, a browser
  without GPS) still quietly falls back to typing the place by hand.
- Your personal weapons now stick around: the guns you add are saved on-device
  and are still there after you close and reopen the app, with no network needed.
  Storage sits behind a `WeaponStore` interface (`shared_preferences`), mirroring
  the session store — the list is loaded once at launch and rewritten whenever you
  add or remove a weapon.
- Spec 0005: the 25 m pistol target and scoring is now written down. It
  documents both faces — the precision face (rings 1–10) and the rapid / duel
  face (rings 5–10) — with their ring sizes, the inner ten ("X"), the black, and
  the .22 vs centre-fire gauge edge, sourced to the ISSF rules. The existing
  geometry is locked behind a vector table of shot positions to expected ring
  for both faces, so it can never silently drift. No app behaviour changes.
- Use your device's location to fill the place in the session-setup step:
  "Bruk min posisjon" now reads a real GPS fix (browser, Android and iOS) via the
  `geolocator` plugin, asking for permission the first time. Typing the place by
  hand stays a full alternative — if location is off, the permission is denied or
  anything goes wrong, the app quietly falls back to manual entry. Browser
  geolocation needs a secure (HTTPS) page, which the deployed app and `localhost`
  both provide.
- Offline session persistence: a whole session — program, weapon, place and time,
  every sealed series and the shots already placed on the series in progress — is
  saved on-device with no network and survives closing the app. Reopening shows a
  "Fortsett økt" card that restores the session to exactly where you left it.
  Storage sits behind a `SessionStore` interface (`shared_preferences`); target
  geometry is rebuilt from the program catalogue, not stored.
- Choose the weapon in the session-setup step: the setup screen now lists the
  weapons permitted for the chosen program, the picked gun travels with the
  session, and its name shows on the scorecard caption.
- A guided multi-stage flow: choosing a program runs the whole thing — you shoot
  each series, the app advances to a fresh face (and switches the target between
  stages, e.g. finpistol presisjon → duell), shows a stage/series counter and the
  running total, and finishes to a session scorecard.
- Zoom in on the target for precise shot placement — with the on-target ＋ / −
  buttons (any device, incl. mouse), a pinch on a touch screen, or a two-finger
  trackpad scroll; pan with two fingers when zoomed. Tapping to place and
  long-pressing to move a shot still work.
- A program picker: the signed-in app opens a list of the official programs, and
  choosing one opens its target (the new pistol faces show their inner-ten
  markers). Each program opens its first stage as a series for now.
- The real program catalogue in code: 10 m air pistol, 25 m standard pistol,
  fin- and grovpistol (precision + duell on two faces) and 50 m fripistol, plus
  the air-pistol and 25 m rapid/silhouette (rings 5–10) target geometries.
- A guided-flow session domain: a pure-Dart `Session` aggregate that walks a
  program's stages and series — advancing to a fresh face, then the next stage —
  and rolls up per-stage and total scores (ADR-0012).
- The program-definition model (`ProgramDefinition` / `StageDefinition`) and a
  seeded catalogue, plus the 25 m pistol precision target geometry and its
  scoring vectors (ADR-0012).
- A program catalogue (`docs/reference/program-catalogue.md`): the authoritative,
  ISSF-sourced list of the in-scope concentric-ring shooting programs and their
  target faces, with confirm-with-the-father flags for NSF-specific values.
- Project scaffolding: a Flutter app for web, Android and iOS.
- Development process: spec-driven workflow, TDD, Conventional Commits enforced
  by a commit-msg hook, strict lints (very_good_analysis), GPLv3 + REUSE
  licensing, and a MkDocs documentation site.
- CI pipeline: commit lint, license check, static analysis, tests, docs build.
- Spec 0001 and a pure-Dart scoring domain for the 10 m air-rifle target
  (integer and decimal scoring), fully unit-tested.
- A tap-to-place target canvas showing the live decimal score.
- Moving a placed shot by long-pressing it and dragging; the marker turns blue
  while being dragged (spec 0002).
- Google sign-in via Supabase: a sign-in gate with sign-out, behind a fakeable
  `AuthRepository` so the feature is testable without real credentials
  (spec 0003, ADR-0010).
- Planning for richer recording: an expanded roadmap (sessions, weapons,
  location, offline-first) and two decisions — the shooting-session domain model
  Program → Stages → Series → Shots (ADR-0012) and offline-first recording with
  deferred sync (ADR-0013).
- A series scoring screen (replacing the single-shot target screen): place a
  series of shots on the target and watch each shot's score and the running
  total in a numbered list, then seal the series once it is complete
  (specs 0004 + 0006).
- The pure-Dart series core: a `Program`, an immutable `Series`, and series
  scoring (per-shot ring, inner-ten count, running total and maximum), with an
  optional inner-ten ring on the target geometry (spec 0004).

### Changed
- The inner-ten count on a scorecard is now shown with a **ringed X** — the way
  an innertier is marked on a paper target — instead of "×X". So "600 · 60×X"
  now reads "600 · 60 Ⓧ", which no longer looks like a multiplication. The badge
  is drawn (not a font character), so it looks the same on web, Android and iOS
  (spec 0023).

### Removed
- The user guide's air-rifle scoring page is gone (in the app and on the
  website). Air rifle is not an offered program, so the guide now covers only
  what you can actually shoot.
- The "Silhuettpistol 12,5 m" home-practice program is no longer offered. It was
  a made-up training format rather than a real NSF program, so it is dropped from
  the program list (the catalogue is back to 13 programs).
- The 10 m air rifle is no longer offered in the program list. At the NSF domain
  expert's request, air rifle is dropped from the program picker (and its now
  orphaned air-rifle weapon class is removed). The scoring foundation it
  introduced is kept intact: spec 0001, the decimal-scoring rules, the
  `TargetGeometry.airRifle10m()` target and the `ProgramCatalogue.airRifle10m`
  reference all remain (the reference still resolves by name, so any session
  recorded before the change still loads) — air rifle is simply not in the
  offered list.
- The 50 m rifle and 300 m rifle programs (and their target faces and weapon
  classes) have been taken out. They had been seeded from ISSF geometry, but the
  NSF domain expert did not recognise them as Norwegian programs, so they rested
  on unconfirmed footing. They are removed entirely until NSF confirms a real
  50 m / 300 m rifle structure.

### Fixed
- You can no longer react with an emoji to **your own** messages — in a
  competition chat or in the forum (threads and replies). Reacting to your own
  post didn't make sense, so the add-reaction button is hidden there and the
  reaction chips on your own posts are display-only (specs 0052, 0055).
- A session you just finished now shows in "Mine økter" immediately, even when
  the connection to your saved sessions is slow or unavailable. Previously the
  list waited to read your account before showing anything, so on the real app a
  slow or stalled cloud read (for example a paused or offline backend) left the
  screen spinning and your just-completed session never appeared. The list now
  shows the sessions saved on your device right away and quietly adds your
  account's synced sessions in the background once they load — with a safety
  timeout so a hanging cloud read can never hold up the screen (spec 0026).
- A session you just finished now shows up in "Mine økter" right away. The list
  used to read your saved sessions once and never refresh, so if you opened the
  (empty) list, went back, completed a session and reopened, the finished
  session was missing until you fully restarted. The list now follows your live
  upload queue, so a just-completed session appears the moment it is recorded,
  and the synced sessions are re-read each time you open the screen. As a
  belt-and-suspenders guard it also reads the durable on-device queue that every
  finished session is saved to, so the just-completed session is shown reliably
  no matter how the recording screen is wired internally (spec 0026).
- The home screen is now fully Norwegian: the title reads "Velg program" and the
  program subtitles count "skudd" instead of "shots".
- Pinch-to-zoom on the target now works on phones in any direction: while a
  finger is on the target the page stops scrolling, so a two-finger pinch (even a
  vertical one) zooms the target instead of being swallowed by the page scroll,
  and a single finger pans it when zoomed (spec 0022).
- Zooming and panning the target now work reliably on web and desktop: while the
  mouse / trackpad pointer is over the target, the wheel zoom and the drag pan
  go to the target instead of scrolling the page, and moving the pointer off it
  restores normal page scrolling (spec 0021).
- New web deploys are no longer served stale: the Flutter service worker is
  disabled for the GitHub Pages build (`--pwa-strategy=none`), and a small
  killswitch in `web/index.html` unregisters any worker left from an earlier build
  and clears its caches, so a reload picks up the latest version instead of a
  cached old one.
- The web app crashed on launch (`Cannot read properties of undefined (reading
  'init')`) because `supabase_flutter` pulls in the Passkeys plugin whose Web
  SDK was missing. Vendored the SDK (`web/bundle.js`) and load it in
  `web/index.html`.
- Google sign-in on web never reached the app: PKCE's code+verifier exchange is
  unreliable on web. Switched to the implicit OAuth flow (session via the URL
  fragment) and rebuilt the auth state as a single-subscription `Notifier`, so a
  pending exchange no longer loops on a spinner and auth errors fall back to the
  sign-in screen.
