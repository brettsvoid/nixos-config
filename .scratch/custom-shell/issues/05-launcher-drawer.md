# Launcher drawer, replacing Fuzzel on Super+R

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

An app launcher drawer that grows out of the frame. It lists installed desktop entries
(Quickshell's DesktopEntries) with icons, filters as you type with fuzzy matching, and
starts the selected app. Most-used apps rank higher; keep the usage counts in a small
file in the shell's state directory.

Design it so later issues can add prefix modes (clipboard history first) without
reworking the drawer: typing a prefix switches what the list shows.

Super+R opens it instead of Fuzzel. Caelestia's Super+Space launcher binding should
also open it once Caelestia is retired; decide whether to keep both keys.

Apps that launch through wrappers today must keep working from the new launcher. The
Nolvus and Steam entries detach on purpose, because Fuzzel and rofi exit straight
after starting them.

## Acceptance criteria

- [ ] Super+R opens the launcher; typing filters; Enter launches; Escape closes.
- [ ] Icons show for installed apps, including ones installed through home-manager.
- [ ] Frequently used apps rank above rarely used ones with the same match quality.
- [ ] Apps that need to detach (Nolvus, Steam games) still start and keep running.
- [ ] Fuzzel is no longer bound to any key (the package can stay until the cheatsheet
      issue removes its last use).
- [ ] Opening the launcher feels instant on both hosts (no visible delay on the first
      open after login).

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop. One deliberate change from the brief,
below.
- `launcher/Launcher.qml` is a Drawer from the top edge, under the bar (drawers are one
  at a time, so the dashboard can share the edge; the OSD keeps the bottom). A search
  field over a fixed-height list (8 rows, so the drawer does not resize while typing);
  Up/Down, Enter, hover and click; Escape closes.
- Modes: the query's prefix picks the mode; `AppsMode` has none. A mode provides
  `prefix`, `placeholder`, `results(query)` and `activate(item)`; clipboard history
  adds one to `modes`.
- Matching: `launcher/fuzzy.js` (ours) scores a subsequence match, favouring word
  starts, consecutive letters, an early start and a whole-query hit, over the name, the
  generic name (×0.7) and keywords (×0.6). Rank = match + 4·log2(1 + starts), so usage
  breaks ties: after one start, "h" put Htop above Heat Signature, which sorts first
  alphabetically. Counts are in `Quickshell.statePath("app-usage.json")`.
- Launching: `DesktopEntry.execute()` runs the command fully detached
  (`execDetached`); `Terminal=true` entries run as `kitty <command>`. Htop started from
  the launcher kept running across a shell restart. Steam and Nolvus entries were not
  started (they would launch games); they run detached the same way.
- Icons: Quickshell only knew hicolor (generic icons came out as Qt's missing-image
  checker). `toggle-shell` and `qs-dev` now export `QS_ICON_THEME` from
  `gtk.iconTheme.name` (Papirus-Dark), so the icons match other apps.
- First open: `shell.qml` reads `DesktopEntries` at start. After a fresh start the
  frame bulged at +44 ms and the panel was sliding out with icons by +81 ms.
- Fixed in Drawer: `shown` now follows the spring's value. It followed `spring.running`,
  which is false for an instant after `open` turns false, so closing from inside the
  content destroyed it mid-call ("Property 'activate' ... is not a function").
- **Change from the brief:** Super+R runs `app-launcher`, which opens this launcher when
  the custom shell's global shortcut is registered (`hyprctl globalshortcuts`) and runs
  Fuzzel otherwise. Removing Fuzzel outright would leave Caelestia sessions and the
  laptop (ambxst's reload drops its own launcher bind) without Super+R until issue 22/23.
  Drop the fallback there. Super+Space stays Caelestia's until Caelestia is retired.
  Tested: with the shell running the wrapper opened the drawer; with it stopped, Fuzzel.
