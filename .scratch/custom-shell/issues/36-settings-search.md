# Searching the settings window

Status: done
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A search field in the settings window (Super+I). Typing lists the matching settings from
every page; choosing one opens its page with the setting in view, briefly highlighted.

- ambxst indexes its settings by loading each panel off screen and reading its labels
  (`modules/widgets/dashboard/controls/SettingsTab.qml`). Ideas only.
- Today the window has ten pages (`settings/SettingsWindow.qml`). Seven are rows of
  `SettingRow` (a label and a schema key) under `PageHeading`s; about 70 schema keys,
  plus the launcher's "Use so far" reset. Window effects, Audio, Network and Bluetooth
  list effects or devices instead. The launcher's `fuzzy.js` already scores matches.

## Proposed choices

1. **What it finds.** **Every row, by its label, heading, page and keywords** (for
   example "am pm" for 12-hour, "blank" for Screens off, "forget" for Use so far), **and
   the other four pages by name and keywords** ("wifi", "password", "pair",
   "headphones", "dissolve"). Alternative: schema rows only. Reason: "wifi" should lead
   somewhere.
2. **The index.** **A hand-kept `settings/index.js`:** one entry per row (`key`, `page`,
   `heading`, `label`, `keywords`) and one per device page. Rows take their label from it
   by key, so each label is written once. `shell.qml` checks at start that every schema
   key has an entry, and warns if not, so the build's load check fails on a missing one.
   Alternative: build the index by making each page off screen and reading its rows, as
   ambxst does. Reason: making the Bluetooth page starts discovery and the effects page
   starts its previews; a list costs nothing.
3. **The field.** **In the sidebar, under "Settings", always shown. Ctrl+F or `/`
   focuses it.** While it has text, the page area lists the results instead: the label,
   and `Page › Heading` under it (two rows are both "Where"), best match first. Up and
   Down move, Enter or a click opens. Escape clears the field; with it empty, Escape
   closes the window, as today. Alternative: a filter on each page. Reason: one field
   finds a setting without knowing its page.
4. **Opening a result.** **Its page opens and scrolls the row into view; the row's
   background flashes once (about one second, then the animation stops).** `OptionsPage`
   gains `reveal(key)`. A device page just opens. The search text stays, so Ctrl+F and
   Down reach the next result.
5. **IPC.** With issue 34 built, its `settings` target gains `search(text)`, which opens
   the window with the text in the field.

Cost: nothing while the window is closed (it exists only while open). Matching runs once
per key press over about 75 entries.

## Acceptance criteria

- [x] "auto" lists Bar › Position › Auto-hide; Enter opens the Bar page with that row in
      view and flashing.
- [x] "wifi" lists the Network page; "12" lists 12-hour.
- [x] Every schema key has an index entry; a missing one fails the build's load check.
- [x] Escape clears the search first, then closes the window.
- [x] Ctrl+Tab, Ctrl+D and Ctrl+U still work while the field is empty.

## Blocked by

- None

## Comments

**2026-10-19:** All five choices approved as proposed, on the review page.

**2026-10-23:** Built as approved, in `qs-test` (headless sway, software rendering), with
real key presses from `wtype -s 300` and clicks from a wlr virtual pointer. Checked:

- "auto" lists Auto-hide (`Bar › Position`) first, then Auto-start, Lock after and
  Calculator. Enter opens Bar with the row lit (a screenshot 0.25 s after Enter shows
  its background tinted; one 1 s later shows it plain again). "long break every",
  a row below the fold, scrolls to the bottom of the page and lights up.
- "wifi" lists the Network page, then Bar › Status icons › Network. "12" lists 12-hour
  alone. "blank" finds Screens off, "forget" Use so far, "dissolve" Window effects,
  "pair" Bluetooth, "headphones" Audio then Bluetooth. A click on the Network result
  opens that page.
- Every schema key has an entry: all 76 rows on the six row pages match the index's
  page, heading and key (a script compared them). With `session.showSleep` removed
  from `index.js`, the home build fails in `custom-shell-config` with `WARN qml:
  settings/index.js has no entry for session.showSleep`; restored, it builds. This
  needed a change to `qs-test`: it only counted warnings that name a QML file, so the
  shell's own `console.warn` passed. It now fails on `WARN qml:` and `ERROR qml:` too.
- Escape with text clears it and shows the page; the next Escape closes the window.
- With the field empty, Ctrl+D, Ctrl+U and Ctrl+Tab work both with the focus on the page
  and with it in the search field (the page scrolls, scrolls back to the same pixels,
  and changes page).
- Down then Enter opens the second result; the text stays; Ctrl+F lists the matches
  again with the same one current, and Down then Enter opens the next (Auto-start on Bar,
  then Lock after on Session).
- `settings search wifi` over IPC (also with the window already open) opens it with the
  text in the field and the matches showing.
- With two outputs and a screen picked on Bar, searching "edge" opens Bar with the pill
  still picked and the Edge row lit.
- The first home build after the rebase on main passed, before this change, so the
  rebase caused no failure.

Beyond the approved text, and why:

- The page is not loaded while the matches show (the Loader is inactive), so a result
  on the page you were on loads it afresh, and Window effects or Bluetooth do not run
  behind the list. Going back to such a page starts it again, as switching to it does.
- The matches show from a flag that typing, Ctrl+F, `/`, a click in the field or IPC set
  and that choosing a result, a sidebar click, Ctrl+Tab or Escape clear, not from the
  field having focus: under `wtype` the window's keyboard focus bounces on each call.
- Ctrl+N and Ctrl+P move through the matches as well as Up and Down, as in the font
  picker. Ctrl+D and Ctrl+U move half a page through them, and so replace Ctrl+D's
  delete-forward in the field.
- A query's words must each match something, so "bar auto" and "auto hide" work.
- A result for a setting that is not per screen, with a screen picked, lands on a faded
  row (as any shared row is while a screen is picked). It still lights up. Say if you
  would rather the search drop back to "All screens".
- "Use so far" has the index key `launcher.useSoFar`, which is not a schema key.
- The Appearance wallpaper picker (swatches, colour scheme) is not a row, so it has no
  entry; searching "wallpaper" finds the three wallpaper rows and the Dashboard tab.

For later issues: a new schema key needs, in the same change, an entry in
`settings/index.js` (`key`, `page`, `heading`, `label`, `keywords`) and a row whose
`label:` is dropped (a `SettingRow` takes its label from the index by `key`). Without the
entry the home build fails. `page` and `heading` must be the page's name and the heading
above the row: nothing checks that, so the results would show the wrong place. A new page
of devices needs one entry with `key: ""`. Issue 40 (more bar entries) and 38 (active
window title) add their keys under Bar → Status icons or a new heading: add the entries
at the same time.

Still to look at on the desktop after the rebuild:

1. Super+I, press `/`, type `auto`: Auto-hide leads. Enter: the Bar page opens with the
   row flashing once. Does the flash read well on your theme (it is the primary colour at
   30 % opacity for 1 s)?
2. `custom-shell settings search wifi` with the window closed, then again with it open on
   another page: the Network page leads the list both times.
