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
