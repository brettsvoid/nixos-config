# Per-monitor settings

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Settings that can differ from screen to screen, for example the bar on the left of the
portrait Dell only, or the wallpaper fitted there. A screen without its own value uses
the shared one, as today. Caelestia reads `monitors/<name>/shell.json` over its main
config and lists the options that ignore it (its README). Ideas only.

Today every setting is shared; only `bar.hiddenScreens` names screens, by connector. The
parts that would read a per-screen value exist once per screen (`frame/ScreenShell`,
`FrameWindow`, `WallpaperWindow`, the bar), or pick a screen (`Drawers.screen`,
`Notifications.screen`, `Osd.screen`). The desktop has DP-1 (Odyssey G5, 2560x1440) and
DP-2 (Dell AW2518H, turned, 1080x1920); `brett-desktop.nix` matches them by EDID
description, so swapped cables change nothing.

## Proposed choices

1. **Which settings.** **Per screen:** `bar.edge`, `bar.autoHide`, `bar.clockSeconds`,
   `bar.clockDate`, `bar.workspaceCount`, `bar.showEmptyWorkspaces`,
   `bar.workspacesPerMonitor`, the five `bar.show*` icons, `bar.volumeLabel`,
   `wallpaper.fill`, `notifications.position`, `osd.position`, `launcher.rows`, and the
   bar entries of issues 38 to 40. **Shared:** the rest. Appearance stays shared because
   one `Theme` serves every screen; the others are behaviour, not layout. Each per-screen
   key gets `perScreen: true` in the schema. Alternative: nearly every setting, as
   Caelestia. Reason: the rest mean little on one screen only.
2. **Storage.** **A `screens` section in the same files:**
   `{"screens": {"<screen>": {"bar": {"edge": "left"}}}}` in settings.json, and
   `local.customShell.settings.screens` in Nix. A shared key there is ignored.
   Alternative: a file per screen (Caelestia). Reason: one file, one watch, one check.
3. **The screen's key.** **Its EDID description** (Hyprland's `description`, for example
   `Dell Inc. Dell AW2518H #ASO0Wsxq3xLd`; only hyprlang needs the `#` doubled). A
   connector name (`DP-2`) also matches, for hand edits. `bar.hiddenScreens` matches
   either, and the window writes descriptions there from now on. Alternative: connector
   names only. Reason: the values stay with the screen, as the host's monitor rules do.
4. **Order.** **Most specific first:** the user's value for the screen, Nix's for the
   screen, the user's shared value, Nix's shared value, the default. Alternative: the
   user before Nix at every level. Reason: otherwise a shared change in the window would
   beat a screen value set in Nix.
5. **In QML.** **`Settings.valueOn(screen, key)`, and a `config/ScreenSettings.qml` made
   once per screen in `ScreenShell`** with a property per per-screen key, handed to the
   frame, bar and wallpaper. `set`, `reset` and `isSet` take an optional screen. With
   issue 34, the `settings` target gains `getOn` and `setOn`.
6. **In the settings window.** **Pills above the page: All screens, then each screen by
   name and model,** on pages with per-screen settings (Appearance, Bar, Launcher,
   Notifications). With a screen picked, per-screen rows edit that screen and their reset
   drops its value; shared rows fade, under a line saying so. In All screens, an
   overridden row says "Differs on DP-2", and a click picks that screen. A screen that is
   not connected keeps a pill while it has values. Alternative: a Screens page listing
   every override. Reason: a setting stays where it is found.
7. **Not here:** a different wallpaper per screen. matugen makes the theme from one
   image; it belongs with issue 78.

Cost: bindings only; no process or timer.

## Acceptance criteria

- [ ] On DP-2 only, the bar goes left and the wallpaper fits; DP-1 does not change. Both
      survive a restart.
- [ ] A screen value from Nix shows as that screen's in the window, and a reset there
      returns to it.
- [ ] Values for a screen that is not connected are kept, and its pill can clear them.
- [ ] A shared key under `screens` is ignored, and the shell loads without warnings.
- [ ] Without a `screens` section nothing changes. Costs nothing in game mode.

## Blocked by

- None
