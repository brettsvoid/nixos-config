# edgebar

A top status bar for macOS in the look of the brett-desktop custom shell, built
with Tauri. It replaces sketchybar on the aerospace window-manager stack:
workspace dots (AeroSpace), a CPU load graph, clock, battery, Wi-Fi, and an
expandable notch with system metrics and a theme picker.

## How it works

Click-through is solved with window *geometry*, not by toggling
`ignore_cursor_events` from a hot loop (which deadlocks on macOS). Two windows:

- **frame**: full-screen and permanently click-through. It draws one shape in
  the surface colour round the screen, with the bar's band as its top edge.
- **bar**: a strip pinned to the top, one window level above the frame. It
  paints the band again, lays the segments on it and grows the drawers out of
  it.

Anything outside the bar's segments and open drawers passes through. See the
header of `src-tauri/src/lib.rs` for the full rationale.

Both windows join every space, so they'd otherwise draw on top of native
fullscreen. A watcher polls the window list twice a second and orders a display's
bar + frame out while an app covers it edge to edge — see `FULLSCREEN_POLL` for
why detection, and not `NSWindowCollectionBehavior`, does the work.

## The notch

The collapsed notch is one slot fed by a priority ladder — an OSD flash
(volume, mic, brightness) outranks per-workspace context, which outranks
whatever is currently making noise. When every provider is silent the WebView
draws the idle look. Rust picks the winner and pushes one `notch` event; see
`src-tauri/src/notch.rs`.

The media readout doesn't use MediaRemote — Apple gated it to entitled
processes in macOS 15.4, so there is no system-wide Now Playing read left.
Instead CoreAudio's process objects say *who is emitting sound* (covering a
YouTube tab, which no metadata API would have reached), and AppleScript adds
title/artist/position for Spotify and Music. Anything else reads as
"<app> · playing". The first AppleScript query prompts once for Automation
access to that player; denied, the readout just stays at the app-level detail.

Several apps are usually audible at once — a long-running bridge like SonoBus
alongside whatever you just hit play on — and CoreAudio's list order means
nothing, so candidates are ranked: a player that reports itself playing wins,
otherwise the most recently started stream does. A paused player never outranks
something actually making noise; it only shows when it's the last thing left.

Configured under `notch` in config.json:

```jsonc
"notch": {
  "idle": "handle",        // "handle" (bare bar) | "clock" | "userHost" | any literal
  "transientMs": 1600,     // how long an OSD flash holds the slot
  "workspaces": {
    "5": { "source": "focusedWindow" },
    "8": { "source": "command", "run": "git -C ~/work status -sb | head -1",
           "everyMs": 30000, "glyph": "terminal" }
  }
}
```

Rules are keyed by AeroSpace workspace name, with `"*"` as the fallback for the
rest. `command` rules run under `/bin/sh` with `$EDGEBAR_WORKSPACE` set, take
the first stdout line as the headline and the second as the dim line, and are
killed after 2s. Workspaces with no rule fall through to the media readout —
which is the point of the ladder.

## Quick toggles

The dashboard's five toggles live in `src-tauri/src/toggles.rs`, one table row
each. Full Disk Access is what makes the Focus file readable (see
[Install](#install) for which app holds the grants).

| Toggle | Read | Write |
|---|---|---|
| Wi-Fi | CoreWLAN `powerOn` | `networksetup -setairportpower` |
| Bluetooth | the `com.apple.bluetooth.power` notify key | IOBluetooth's private power setter, which asks for Bluetooth permission |
| Focus | `~/Library/DoNotDisturb/DB/Assertions.json` (needs Full Disk Access) | runs the Shortcut named in `toggles.focusShortcut` |
| Night Shift | CoreBrightness `CBBlueLightClient` | the same client's `setEnabled:` |
| Caffeine | a `caffeinate -di -w <edgebar's pid>` child is alive | starts or kills that child |

donotdisturbd refuses XPC from unentitled processes, so the Focus toggle stays
read-only until a Shortcut called "Toggle Focus" exists. Make one in Shortcuts
with a single **Set Focus** action set to Do Not Disturb and Toggle. Settings,
Dashboard renames it (`toggles.focusShortcut`), and the toggle follows at once.

## Config & theming

Both are Nix-rendered, not committed live files:

- `~/.config/edgebar/config.json` — geometry + colour roles. Rendered by
  `modules/home/darwin/edgebar.nix` from `src-tauri/config.default.json` (also
  the binary's bundled fallback), with `geometry.barHeight` single-sourced from
  `flake.lib.barGeometry`.
- `~/.config/edgebar/palette.json` — wallpaper-derived colours. `matugen`
  (`modules/home/darwin/edgebar/matugen`) generates it and pings edgebar's
  `theme.sock` to re-theme live.

What the user changes in the app goes in a third file, because `config.json` is
a read-only store symlink. `~/.config/edgebar/settings.json` holds only the keys
the user changed, and only edgebar writes it, atomically. The running config is
the bundled `config.default.json`, then `config.json`, then this file, merged key
by key (`src-tauri/src/settings.rs`). Defaults live only in
`config.default.json`. An override must sit at a path that file has and have the
type it has there (an empty object such as `notch.workspaces` takes any keys). A
bad override is left out and listed in the snapshot's `error`. A file that is not
valid JSON is ignored whole and never written over. `src/settings.ts` is the
WebView's typed accessor (`current`, `set`, `reset`, `onChange`).

`set_setting` changes the running bar without a restart: the theme when colours,
appearance, geometry or `notch.idle` change, the native frame and bar windows
when geometry changes, the notch rules when `notch.workspaces` or
`notch.transientMs` change, and the Focus toggle when `toggles.focusShortcut`
changes. Keys only the WebView reads (`clock.*`, `segments.cpu`,
`calendar.weekStart`) take effect from the `settings` event. Setting the same
value again does nothing.

The light/dark/auto mode is the `appearance` setting, whichever control sets
it. It used to live in `~/.config/edgebar/appearance` as well; edgebar imports
that file once at startup (as an override only when it differs from the
layers below) and deletes it.

### The Settings view

The notch's Settings tab (the gear at the foot of the rail) edits these
settings: one section per area, each row with an undo button while its key is
overridden, and a banner when part of settings.json was refused. Its Setup
section lists what edgebar needs from this Mac (`src-tauri/src/setup.rs`, one
table row per check): Full Disk Access, Bluetooth permission, Automation for
Spotify and Music, the Focus Shortcut, and the `aerospace`, theme, wallpaper
and Claude commands. A check never asks for anything; its button does (a
System Settings pane, the Shortcuts app, or one guarded AppleScript read so
macOS asks for Automation). Each row names the app its grant goes to, which is
edgebar's responsible process: `edgebar.app`, or kitty while `pnpm tauri dev`
runs edgebar in herdr. A missing item puts a dot on the Settings rail button.

The ink drawn on the surface (`colors.text`) is contrast-checked against it.
If the role map's ink falls under 4.5:1 (WCAG AA), edgebar uses the palette
colour that contrasts most instead, or plain black or white if no palette colour
clears it. The theme view's **Ink** control overrides the check: it sets an
explicit ink for the light or dark scheme in effect and saves it to
`~/.config/edgebar/ink.json`. **Auto** clears the override.

The accent (the active workspace, the active rail button, every selected state)
gets the same check, with WCAG's 3:1 floor for graphical indicators. It names
`primary|rosewater`: the first key the palette has wins, so a palette rendered
before the template had `primary` still themes.

### Wallpaper folder, OLED and Tint

Three keys in `config.default.json`, changeable as settings:

- `wallpaper.folder` — where the wallpapers view looks (`~` allowed). Images one
  subfolder down are listed too, each tagged with its subfolder and file type.
  The `select-wallpaper` and `cycle-wallpaper` commands pick from the same
  folder (`edgebar-wallpaper-folder` prints it).
- `oled` — in the dark scheme the palette's surface becomes `#000000`, and every
  role built on it follows. The light scheme is unchanged. (It sits at the top
  level, not under `appearance`, because `appearance` is already a string.)
- `wallpaper.tint` — repaints the desktop picture in the theme's colours, after
  ambxst's `palette.frag`. The palette still comes from the original picture;
  the repainted copy is a PNG in `~/.cache/edgebar/tinted/` with a `.src` file
  naming its original. The copy is rebuilt when the scheme, appearance or OLED
  changes, and the original goes back on the desktop when tint is turned off.
  HEIC pictures are not tinted. To stop the launchd watcher theming from the
  copy, edgebar touches `~/.cache/edgebar/.inapp-change` before each desktop
  change, and `generate-edgebar-theme` maps a copy back to its original.

`modules/home/darwin/edgebar.nix` owns deployment; edit config/palette there and
rebuild. See also [../../docs/bar-spec.md](../../docs/bar-spec.md) for edgebar's
design spec.

## Install

`package.nix` builds `edgebar.app` with Nix, and
`modules/home/darwin/edgebar.nix` installs and starts it:

- Activation copies the app out of the store to `~/Applications/edgebar.app`
  when the build changes, signs the copy, and restarts the bar.
- The launchd agent `org.nix-community.home.edgebar` starts it at login and
  again if it exits. It logs to `/tmp/edgebar.log`.

The signing keeps the macOS permissions across rebuilds. Nix leaves the app
signed ad hoc, and macOS knows an ad hoc app by its hash, so every rebuild
would look like a new app. Signed with the `edgebar-codesign` certificate, the
app is known by its bundle id and certificate, which don't change. Each Mac
needs that certificate once, in the login keychain: Keychain Access ›
Certificate Assistant › Create a Certificate, Name `edgebar-codesign`, Identity
Type Self-Signed Root, Certificate Type Code Signing. Tick "Let me override
defaults" and set the validity to 3650 days, because a new certificate means
granting the permissions again. Without the certificate, activation says so
and installs the app signed ad hoc.

`src-tauri/Info.plist` is merged into the bundle's own. It keeps the Dock icon
hidden from launch and gives the Bluetooth and Automation prompts their text.

When `pnpm-lock.yaml` changes, update `pnpmDeps.hash` in `package.nix`: set it
to `lib.fakeHash`, rebuild, and copy the hash from the error.

## Development

Stop the installed bar first. A second edgebar takes over the bar's sockets and
draws a second bar on top:

```sh
launchctl bootout gui/$UID/org.nix-community.home.edgebar      # stop
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/org.nix-community.home.edgebar.plist  # start
```

```sh
pnpm install
pnpm tauri dev      # run the bar
pnpm tauri build    # release build
```

Vite does not watch `src-tauri/`, and the WebView types and seeds its settings
from `src-tauri/config.default.json`. After adding a key there, restart
`pnpm tauri dev`, or the WebView keeps the old file and reads the new key as
undefined.
