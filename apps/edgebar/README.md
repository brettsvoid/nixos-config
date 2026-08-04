# edgebar

An ambxst-style top status bar for macOS, built with Tauri. It replaces
sketchybar on the aerospace window-manager stack: workspace dots (AeroSpace), a
CPU load graph, clock, battery, Wi-Fi, and an expandable notch with system
metrics and a theme picker.

## How it works

Click-through is solved with window *geometry*, not by toggling
`ignore_cursor_events` from a hot loop (which deadlocks on macOS). Two windows:

- **frame** — full-screen, transparent, permanently click-through: the bezel.
- **bar** — a thin interactive strip pinned to the top: the pills.

Anything outside the top strip lands on the frame and passes through to the app
underneath. See the header of `src-tauri/src/lib.rs` for the full rationale.

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

## Config & theming

Both are Nix-rendered, not committed live files:

- `~/.config/edgebar/config.json` — geometry + colour roles. Rendered by
  `modules/home/darwin/edgebar.nix` from `src-tauri/config.default.json` (also
  the binary's bundled fallback), with `geometry.barHeight` single-sourced from
  `flake.lib.barGeometry`.
- `~/.config/edgebar/palette.json` — wallpaper-derived colours. `matugen`
  (`modules/home/darwin/edgebar/matugen`) generates it and pings edgebar's
  `theme.sock` to re-theme live.

`modules/home/darwin/edgebar.nix` owns deployment; edit config/palette there and
rebuild. See also [../../docs/bar-spec.md](../../docs/bar-spec.md) for the shared
edgebar ⇄ quickshell design spec.

## Development

```sh
pnpm install
pnpm tauri dev      # run the bar
pnpm tauri build    # release build
```
