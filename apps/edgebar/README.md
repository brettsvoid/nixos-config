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
each. edgebar inherits kitty's permissions through herdr, which is what makes
the Focus file readable.

| Toggle | Read | Write |
|---|---|---|
| Wi-Fi | CoreWLAN `powerOn` | `networksetup -setairportpower` |
| Bluetooth | the `com.apple.bluetooth.power` notify key | IOBluetooth's private power setter, which asks for Bluetooth permission for kitty |
| Focus | `~/Library/DoNotDisturb/DB/Assertions.json` (needs Full Disk Access) | runs the Shortcut named in `toggles.focusShortcut` |
| Night Shift | CoreBrightness `CBBlueLightClient` | the same client's `setEnabled:` |
| Caffeine | a `caffeinate -di -w <edgebar's pid>` child is alive | starts or kills that child |

donotdisturbd refuses XPC from unentitled processes, so the Focus toggle stays
read-only until a Shortcut called "Toggle Focus" exists. Make one in Shortcuts
with a single **Set Focus** action set to Do Not Disturb and Toggle.

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
when geometry changes, and the notch rules when `notch.workspaces` or
`notch.transientMs` change. Setting the same value again does nothing.

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

`modules/home/darwin/edgebar.nix` owns deployment; edit config/palette there and
rebuild. See also [../../docs/bar-spec.md](../../docs/bar-spec.md) for edgebar's
design spec.

## Development

```sh
pnpm install
pnpm tauri dev      # run the bar
pnpm tauri build    # release build
```
