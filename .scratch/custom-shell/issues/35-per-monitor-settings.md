# Per-monitor settings

Status: done
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

- [x] On DP-2 only, the bar goes left and the wallpaper fits; DP-1 does not change. Both
      survive a restart.
- [x] A screen value from Nix shows as that screen's in the window, and a reset there
      returns to it.
- [x] Values for a screen that is not connected are kept, and its pill can clear them.
- [x] A shared key under `screens` is ignored, and the shell loads without warnings.
- [x] Without a `screens` section nothing changes. Costs nothing in game mode.

## Blocked by

- None

## Comments

**2026-10-19:** All seven choices approved as proposed, on the review page.

**2026-10-23:** Built as approved (commit `custom-shell: per-monitor settings, under
screens in the same files`). Status is ready-for-human: everything was checked headless
with `qs-test`, not yet on the desktop's own DP-2. The first criterion stays unticked
until then.

How it works: `settings.json` and `local.customShell.settings` take a `screens` section,
for example `{"screens": {"Dell Inc. Dell AW2518H #ASO0Wsxq3xLd": {"bar": {"edge":
"left"}}}}`. A connector name (`DP-2`) works as the key too. In Nix:

```nix
home-manager.users.brett.local.customShell.settings.screens."Dell Inc. Dell AW2518H #ASO0Wsxq3xLd".bar.edge = "left";
```

From the command line: `custom-shell settings setOn DP-2 bar.edge '"left"'`, `getOn DP-2
bar.edge`, `resetOn DP-2 bar.edge`. A screen can be named by connector or description;
the value is stored under the description.

Checked, with two headless outputs whose fake Hyprland gave them the desktop's real
descriptions (`qs-test -s 2 -m monitors.json`, new in this commit):

- DP-2 only: `setOn "Dell Inc. Dell AW2518H #ASO0Wsxq3xLd" bar.edge '"left"'` and
  `setOn HEADLESS-2 wallpaper.fill '"fit"'` both wrote under the description.
  `getOn HEADLESS-2` then gave `"left"` and `"fit"`; `getOn HEADLESS-1` and the shared
  `get` gave `"top"` and `"crop"`. Screenshots (the Dell output turned to portrait): a
  left bar with the vertical clock and a letterboxed wallpaper on it, and no change on
  the other output. After the shell was killed and started again, the same values and
  the same screenshots, and no QML warning in its log.
- Nix: with `defaults.json` holding `bar.edge` `right` for the Dell and `settings.json`
  `bottom`, clicking the Dell's pill (virtual pointer) showed Edge on Bottom with a
  reset button. The reset left `right` filled with no reset button; `getOn` gave
  `"right"` and the file kept only the Dell's other key.
- Not connected: `Old Screen ABC 123` with `launcher.rows` 12 and `bar.clockDate` false
  got a pill. All screens showed "Differs on Old Screen ABC 123" on Rows and Date.
  Picking it showed "Not connected." and Rows at 12, with Rank by use faded. "Forget its
  settings" removed it from the file and its pill went; `getOn` then refused it as an
  unknown screen. Clicking "Differs on HEADLESS-2" picked that screen.
- Shared keys under `screens` (`appearance.textScale` 1.5, `frameThickness` 20,
  `clock.twelveHour`, `bar.volumeStep`) changed no pixel on either output (`compare
  -metric AE`: 0). A screen with only shared keys got no pill. `getOn` refuses them: `error:
  appearance.textScale is the same on every screen`. `qs-test --check` passes with them.
- No `screens` section: this commit's shell and the one before, side by side with no
  settings, gave screenshots with 0 differing pixels on both outputs, and the same
  warnings (none from QML). Resources, one run each: RSS 235.8 MB at rest against 234.2
  before, 216.6 MB in game mode against 215.8; 0 CPU ticks in 10 s, at rest and in game
  mode, for both. Nothing new runs: bindings only.
- Also: the Screens pills under Bar hide the Dell by writing its description to
  `bar.hiddenScreens`, and a second click removes it. `launcher.rows` 4 on one screen gave
  a shorter launcher there than on the other. With `notifications.position` bottom-left
  and `osd.position` top on the focused screen only, the pop-up and the OSD showed there.
- `nix develop -c pre-commit run --all-files` passes. brett-desktop's and
  brett-msi-laptop's homes build (`qs-test --check` included).

Beyond the approved text, and why:

- `resetOn` beside `getOn` and `setOn`, so a screen value set from the command line can
  be removed from it.
- `setOn` and `getOn` refuse a screen that is neither connected nor stored, and a shared
  setting, with an `error:` line, as the other IPC functions do.
- The window's pills show the connector and the model Qt reports; a screen that is not
  connected shows the name it is stored under.
- On Appearance, the wallpaper picker below the rows fades too while a screen is picked,
  as it sets one wallpaper for all (choice 7).
- "Forget its settings" shows only for a screen that is not connected. It removes the
  user's values; Nix's stay, and keep its pill.

For later issues: a new per-screen setting is `perScreen: true` in the schema and a
property on `config/ScreenSettings.qml`; the window picks it up from the schema. The bar
entries of issues 38 to 40 should go there.

Still to check, on the desktop after the rebuild:

1. `custom-shell settings setOn DP-2 bar.edge '"left"'` and `custom-shell settings setOn
   DP-2 wallpaper.fill '"fit"'`. The Dell's bar goes to the left and its wallpaper shows
   whole; the Odyssey does not change. `toggle-shell restart`: both stay.
2. `cat ~/.config/custom-shell/settings.json`: the values are under `"Dell Inc. Dell
   AW2518H #ASO0Wsxq3xLd"`. If the key is `DP-2` instead, Hyprland's description did not
   reach the shell; say so.
3. Settings, Bar: the pills read `DP-1 · Odyssey G5` and `DP-2 · Dell AW2518H` (or what
   Qt calls them). Pick DP-2, reset Edge and Fill (Appearance); the bar returns to the top.
4. Question: keep these values on DP-2, or set them in `brett-desktop.nix` instead?

When 1 and 2 hold, tick the first criterion and set the status to done.

**2026-10-23 (later):** The user wants the Dell's values kept in `settings.json` for now, not in `brett-desktop.nix`. Criterion 1 on the real Dell was not reported on yet.

**2026-10-23 (later still):** Checked by the user on the desktop: `setOn DP-2 bar.edge` put the Dell's bar on the left, and it stayed there after a restart. The wallpaper fit on DP-2 was checked headless only (screenshots, 2026-10-23); it reads its value through the same per-screen path as the bar.
