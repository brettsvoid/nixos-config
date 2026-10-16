# Launcher search by field

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Prefixes that search apps by one field of their desktop entry: category, description,
command or keywords, or only the terminal apps. `@c game` lists the games, and
`@e steam` lists the entries that run Steam.

- Caelestia has `@i`, `@c`, `@d`, `@e`, `@w`, `@g`, `@k` and `@t`
  (`modules/launcher/services/Apps.qml`). Ideas only.
- Today `AppsMode` matches the name, the generic name (×0.7) and the keywords (×0.6)
  with `fuzzy.js`. Quickshell's `DesktopEntry` also has `categories`, `comment`,
  `execString`, `startupClass`, `id` and `runInTerminal`.

## Proposed choices

1. **`@`, one letter and a space**: `@c` categories, `@d` description (Comment), `@e`
   command (Exec), `@k` keywords, `@t` terminal apps by name. Alternative: Caelestia's
   full set, which adds `@i` id, `@w` window class and `@g` generic name. Reason: those
   three are rarely wanted, and the generic name is searched already.
2. **`@` alone lists the fields as rows. Enter on one puts its prefix in the field**
   (a new row kind, `fill: "@c "`, which sets the field's text). Reason: no letters to
   remember.
3. **The same ranking as the apps mode**: the field's match (the best item, for
   categories and keywords) plus the use bonus. The subtitle shows the matched field
   ("Game; Simulation"). Hidden apps (issue 45) stay hidden.
4. **A help prefix, `?`, lists every mode's prefix as rows**, and the apps placeholder
   shrinks to "Search apps, or ? for more". Alternative: the placeholder keeps naming
   each prefix. Reason: with issues 41 to 43 there are seven prefixes, too many for the
   560-pixel field.
- Settings: `launcher.fieldPrefix` (`@`) and `launcher.helpPrefix` (`?`), with the
  other prefixes on the Launcher page.
- Cost: none beyond today's search. Nothing runs, so nothing in game mode.

## Acceptance criteria

- [ ] `@c game` lists only apps whose categories match "game".
- [ ] `@e steam` matches the command, `@d` the description and `@k` the keywords.
- [ ] `@t` lists only `Terminal=true` apps.
- [ ] `@` alone lists the fields, and Enter on one fills in its prefix.
- [ ] `?` lists every prefix as the settings have it, and Enter on one fills it in.
- [ ] A prefix changed in the settings window changes both lists at once.

## Blocked by

- None
