# Active window title in the bar

Status: ready-for-agent
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

- [ ] Each screen's bar shows its own last focused window, and follows a title change
      (switching a browser tab).
- [ ] A long title elides before the clock on the Dell (1080 px wide).
- [ ] Hover opens the panel with a preview; each button acts on that window, even when
      another window has focus.
- [ ] Close asks the app to close; nothing is killed.
- [ ] Nothing is captured while the panel is closed. Costs nothing in game mode.

## Blocked by

- .scratch/custom-shell/issues/37-bar-popouts.md

## Comments

**2026-10-19:** All four choices approved as proposed, on the review page. The window panel (choice 3) still waits on issue 37, so the title in the bar and the settings can be built first.
