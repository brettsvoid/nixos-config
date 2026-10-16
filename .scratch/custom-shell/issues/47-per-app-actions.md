# Launcher: options for the selected row (per-app actions)

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A list of options for the selected launcher row. For an app it holds the desktop file's
own actions, for example Firefox's New Window, New Private Window and Profile Manager,
and Steam's Store, Library and Big Picture (read in the installed `.desktop` files).
Other modes add their own options: issues 43, 45 and 46 use this list.

- ambxst opens Launch, Pin to dock and Create shortcut under an app on Shift+Enter or a
  right click (`modules/widgets/launcher/LauncherView.qml`). Ideas only.
- Builds on `launcher/Launcher.qml` and Quickshell's `DesktopEntry.actions`. Each
  `DesktopAction` has `name`, `icon`, `command` and `execute()` (detached, field codes
  such as `%U` dropped).

## Proposed choices

1. **Tab, or a right click, shows the selected row's options in place of the results.
   Escape or Shift+Tab goes back.** Alternatives: Shift+Enter (ambxst); a pop-up menu
   beside the row. Reason: the drawer keeps its size, and the list's keys, hover and
   confirm work as they are. The field takes Escape first while options show, so a
   second Escape closes the drawer (as `settings/TextRow.qml` does).
2. **A mode gives options through an optional `options(item)`.** It returns rows in the
   results' shape, each with `run()`. An option can have `confirm: true`, or
   `ask: "<prompt>"` for a line of text: the field empties, shows the prompt as its
   placeholder, and Enter calls `run(text)`. Issue 43 renames with it, and issue 46
   sets aliases. Alternative: options fixed per mode in `Launcher.qml`. Reason: each
   mode knows its own items.
3. **A row that has options shows a chevron (›) at its right.** Alternative: no mark.
   Reason: without one, Tab is hard to find.
4. **An app's options start with its desktop actions**, run as apps run (`execute()`,
   and `Terminal=true` entries through `launcher.terminal`, as `AppsMode.activate`
   does). Alternative: also list each action as its own search result ("Firefox: New
   Private Window"), as Fuzzel's `show-actions` does. Reason: one row per action
   crowds the search.
5. **Pin to dock belongs to issue 72**, which keeps the pinned list and adds "Pin to
   dock" and "Unpin from dock" here.
6. **No desktop shortcut for now.** `hyprland.nix` sets `xdg.userDirs.desktop = null`
   on purpose (no desktop icons on a tiling setup), so `~/Desktop` does not exist. If
   issue 73 brings desktop icons, it adds "Add to desktop" here. Alternative: write
   `~/Desktop/<id>.desktop` now, which nothing shows.
- No settings, packages, processes or timers. Costs nothing in game mode.

## Acceptance criteria

- [ ] Tab or a right click on Firefox lists New Window, New Private Window and Profile
      Manager. Enter on one opens it, and the launcher closes.
- [ ] Escape returns to the same query and results. A second Escape closes the drawer.
- [ ] An option with `ask` takes a line of text. An option with `confirm` waits for a
      second Enter.
- [ ] A row without options shows no chevron, and Tab on it does nothing.

## Blocked by

- None
