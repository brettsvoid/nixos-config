# Searching the settings window

Status: ready-for-human
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

- [ ] "auto" lists Bar › Position › Auto-hide; Enter opens the Bar page with that row in
      view and flashing.
- [ ] "wifi" lists the Network page; "12" lists 12-hour.
- [ ] Every schema key has an index entry; a missing one fails the build's load check.
- [ ] Escape clears the search first, then closes the window.
- [ ] Ctrl+Tab, Ctrl+D and Ctrl+U still work while the field is empty.

## Blocked by

- None
