# Active window title in the bar

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

The bar shows the active window's app icon and title, after the workspaces. Resting the
pointer on it opens a window panel (a popout, issue 37): a still preview of the window
and buttons to float or tile it, pin it, make it fullscreen, send it to a workspace, or
close it.

- Caelestia shows the title, with a preview on hover that opens a window info panel
  (`modules/bar/popouts/ActiveWindow.qml`, `modules/windowinfo/`). ambxst shows the
  title in its notch when nothing plays. Ideas only.
- Quickshell's Hyprland module gives `Hyprland.activeToplevel` and, per window, a live
  `title`, its `monitor` and `workspace`, and `wayland.appId`. A window opened after the
  shell started has no class in `lastIpcObject` (Quickshell's `openwindow` handler keeps
  only the title and workspace), so the app id comes from `wayland.appId`.
- Icons: `DesktopEntries.heuristicLookup(appId)`, then `Quickshell.iconPath`, as the
  launcher does. Preview: `ScreencopyView`, which captures a window through Hyprland's
  toplevel export.

## Proposed choices

1. **Which window.** **Each bar shows the window last focused on its own screen,** dimmed
   while focus is on the other screen. A small service records `Hyprland.activeToplevel`
   against its monitor when it changes; a screen not yet focused shows its active
   workspace's first window. Alternative: every bar shows the one focused window.
   Reason: the other screen's bar would name a window it does not show.
2. **What shows.** **The app icon and the title, elided to fit before the clock.** With
   no window, nothing. On a side bar, the icon only. Alternative: the app's name instead
   of the title. Reason: the title says which document or page.
3. **The panel.** **A still preview taken when the panel opens (`live: false`, then
   `captureFrame()`), about 320 px wide, then the title, app id and workspace, and
   buttons:** Float or Tile, Pin (while floating), Fullscreen, a row of workspace
   numbers to send it to, and Close (`closewindow`, which asks the app). They use
   `Hyprland.dispatch` with the window's address, as `bar/Workspaces.qml` does: no
   process. These new dispatch sites join the list in
   `.scratch/hyprland-lua-config/issues/01-move-to-lua.md`. Alternatives: a live
   preview, as Caelestia; a Kill button (`killwindow`). Reason: a live copy costs GPU
   time on every frame the window draws, and is unmeasured on the 3080 Ti.
4. **Settings.** `bar.showWindowTitle` and `bar.windowPanel` (both on), on the Bar page;
   per screen with issue 35.

Cost: bindings on the Hyprland module's data; no process, no timer. One frame captured
per panel opening. In game mode and fullscreen the bar is hidden: nothing.

## Acceptance criteria

- [x] Each screen's bar shows its own last focused window, and follows a title change
      (switching a browser tab). (A terminal's title escape in a nested Hyprland; a
      real browser tab not tried.)
- [x] A long title elides before the clock on the Dell (1080 px wide). (A 1080 px wide
      output in a nested Hyprland; the Dell itself not tried.)
- [ ] Hover opens the panel with a preview; each button acts on that window, even when
      another window has focus.
- [ ] Close asks the app to close; nothing is killed.
- [ ] Nothing is captured while the panel is closed. Costs nothing in game mode.

## Blocked by

- .scratch/custom-shell/issues/37-bar-popouts.md

## Comments

**2026-10-19:** All four choices approved as proposed, on the review page. The window panel (choice 3) still waits on issue 37, so the title in the bar and the settings can be built first.

**2026-10-23:** The title in the bar is built (choices 1, 2 and 4); the panel (choice 3)
still waits on issue 37 and is not started, so the panel criteria stay open and the issue
stays blocked by 37 for that part. Built and checked in a real Hyprland 0.56.2 nested in a
headless mutter, with two outputs (1920x1080 and a rotated one, 1080 px wide) and kitty
windows:

- Choice 1: each bar named the window last focused on its own screen. With two windows on
  one screen, focusing the older, then the other screen, kept the older on the first bar;
  focusing the newer, then the other screen, kept the newer. The bar of the screen without
  focus ran at opacity 0.5 and went back to 1 on focus (logged at each end of the fade).
  Closing the recorded window while its screen was unfocused moved the bar to the
  workspace's other window; closing the last one hid the entry. A screen switched to an
  empty workspace showed nothing. After a shell restart the screens showed their
  workspaces' windows. The record keeps a screen's window while its workspace is active:
  Quickshell ignores `activewindowv2` with no address, so `activeToplevel` alone would name
  a window on another workspace (`services/ActiveWindows.qml`).
- Choice 2: a title change (OSC 2 from the terminal) showed at once. A 300-character title
  stopped 16 px before the clock on the 1080 px output (screenshot: elided with an
  ellipsis; the bar's own gap is `Theme.spacingLarge`). The icon came from the desktop
  entry (kitty's own icon), and for an app with no entry, the app id and then
  `application-x-executable`. On a left-edge bar only the icon showed, centred under the
  workspaces. A window opened after the shell started got its app id from `wayland.appId`
  a moment after its title (the icon and title update when it arrives).
- Choice 4: `bar.showWindowTitle` is on the Bar page under "Active window", per screen
  (set off on one output, the other kept it; the row said "Differs on HEADLESS-1"), and
  the settings search finds "window title". `bar.windowPanel` is not added: with no panel
  it would be a switch that does nothing. Issue 37's work adds it, with its schema key,
  `ScreenSettings` property, index entry and row.
- Cost: a shell at rest, two windows open, 40 s each: 203 and 211 MB RSS before, 205 and
  206 MB after, 0 to 1 CPU ticks either way (`/proc/<pid>/stat`, two runs each). No
  process, no timer. In game mode the bar is hidden, so nothing paints; its bindings only
  run when Hyprland sends a window event.

For the panel (issue 37 and this issue's choice 3): `ActiveWindows.on(monitor)` returns
the `HyprlandToplevel` a bar shows, so the panel can take it from there (`address` for
`Hyprland.dispatch`, `wayland` for `ScreencopyView`). Hovering `bar/WindowTitle.qml` is the
place for the popout's trigger. The panel would need to read the same window the bar
shows, not `Hyprland.activeToplevel`. Not checked on the desktop: the real Dell, browser
tabs, Papirus icons (the nested test used breeze through `QS_ICON_THEME`).

To check on the desktop, after a rebuild:

1. Focus a browser on the Dell and switch tabs: does the Dell's bar follow the tab title,
   with the browser's icon (Papirus)?
2. Move focus to the other screen: does the Dell's bar dim but keep its window?
3. Open a page with a very long title on the Dell: does it end in an ellipsis with a
   gap before the clock?
4. Settings, Bar, Active window: does the switch hide it on the screen picked only?
