# Custom Quickshell shell

Status: planning (2026-10-09)

## Goal

A Quickshell shell of our own that replaces Caelestia on brett-desktop and ambxst on
brett-msi-laptop. It takes Caelestia's look and the best ideas from ambxst, and avoids
the performance costs of both. It is prototyped inside nixos-config (the shell in
`modules/home/desktop/quickshell`, wired up by `modules/home/desktop/custom-shell.nix`)
and may move to its own repo later.

## Decisions

- **Licence: rewrite, never copy.** Caelestia is GPL-3.0 and ambxst is AGPL-3.0; this
  repo is MIT. Read their code for ideas and techniques, and reuse values that come from
  public specs (Material 3 motion and shape tokens), but write every line and shader
  ourselves.
- **Look: Caelestia's.** A frame around the screen edge, with drawers that grow out of
  it as one merged shape. The bar is at the top (Caelestia only offers a left bar).
- **edgebar and this bar go their own ways.** `docs/bar-spec.md` no longer binds this
  shell. They may be reunited later.
- **Native code is Rust.** By default a separate Rust program that the shell starts and
  reads JSON lines from. An in-process cxx-qt QML plugin only where data arrives at
  frame rate (the audio visualiser).
- **Both hosts get the same setup.**
- **Fuzzel is replaced** (launcher on Super+R, keymap cheatsheet on Super+/). Its layout
  is fixed (one box with a list, no animation) so it cannot match the frame look. The
  rofi game library stays.

## Architecture (from the 2026-10-09 research)

- **Windows per screen.** One full-screen transparent window on the **Top** layer, with
  an input mask that covers only the frame and the open panels, so clicks pass through
  everywhere else. Four 1-pixel windows reserve the screen edges (exclusive zones), so
  panels can animate without windows re-tiling. A separate window on the background
  layer holds the wallpaper. Caelestia and ambxst both arrived at this layout.
  Never the Overlay layer for always-mapped surfaces: Caelestia found it stops Hyprland
  sending fullscreen games straight to the display (their #1377).
- **Frame and panels are one signed-distance shape** drawn by one shader. A smooth
  minimum joins each panel's rounded box to the frame, which gives the concave fillets.
  The drop shadow comes from the same distance field in the same pass.
- **Drawers** slide out from behind the frame. Their content sits in Loaders that are
  only active while the drawer shows.
- **Motion and shape.** Material 3 Expressive easing (for example the default spatial
  curve `cubic-bezier(0.38, 1.21, 0.22, 1.00)` and fast spatial
  `cubic-bezier(0.42, 1.67, 0.21, 0.90)`), spatial durations around 350/500/650 ms and
  effect durations around 150/200/300 ms. Check the values against m3.material.io
  before relying on them; they were read from Caelestia, not from the spec.
- **Theme.** matugen, already wired: `generate-theme` writes
  `~/.cache/qs-theme/colors.json` and the `Theme` singleton watches it.
- **Use Quickshell's built-in modules first:** Hyprland, PipeWire, UPower,
  Notifications, SystemTray, Mpris, Bluetooth, Networking, Pam, session lock,
  ScreencopyView, GlobalShortcut, IpcHandler, DesktopEntries, ColorQuantizer.
  Quickshell has no CPU/GPU/memory statistics and no audio spectrum; those are the Rust
  jobs.

## Performance rules

These come from the known costs in Caelestia and ambxst.

1. No `layer.enabled` + `MultiEffect` (or any offscreen effect) over a full-screen item.
   Both shells do this for their shadow, and it re-blurs a screen-sized buffer on every
   change.
2. Never start a process in response to a Hyprland event. ambxst runs
   `hyprctl clients -j | jq` on nearly every focus and title change. Use the Hyprland
   module's data.
3. Pollers run only while something visible uses them (reference-counted, as
   Caelestia's ticking services do).
4. Nothing animates or repaints while nothing changes: no perpetual Canvas repaints, and
   animations stop when hidden or paused.
5. Avoid clipping-rectangle primitives in repeated components (each one is an offscreen
   layer plus a shader).
6. No `nvidia-smi` per tick. GPU statistics come through NVML in Rust.
7. Measure before adding: Caelestia forces the threaded render loop after choppy
   animation reports on NVIDIA (their #153).
8. Game mode makes the shell step aside (see the game mode issues).

## Reference material (read for ideas only)

Pinned sources in the Nix store come from the flake inputs `caelestia-shell` and
`ambxst`.

- **Caelestia** (rev 454f46d):
  - Frame, mask and edges: `modules/drawers/ContentWindow.qml`, `Exclusions.qml`,
    `Regions.qml`, `Interactions.qml`.
  - The shape shader and spring physics: `plugin/src/Caelestia/Blobs/` (`shaders/blob.frag`,
    `blobrect.cpp`).
  - Tokens: `plugin/src/Caelestia/Config/tokens.hpp`.
  - Colours: `services/Colours.qml`.
- **ambxst** (rev 59edec9):
  - Reserved edges: `modules/shell/ReservationWindows.qml`.
  - One surface with a mask: `modules/shell/UnifiedShellPanel.qml`.
  - Lazy dashboard tabs: `modules/widgets/dashboard/Dashboard.qml`.
  - Event-driven clipboard: `scripts/clipboard_watch.sh`.
  - Wallpaper recolour shader: `modules/widgets/dashboard/wallpapers/palette.frag`.
  - Launcher prefix modes: `modules/widgets/launcher/`.
- **Costs to avoid:**
  - ambxst's full-screen shadow: `UnifiedShellPanel.qml:164-169`.
  - ambxst's `hyprctl` per event: `modules/bar/workspaces/HyprlandData.qml:56-92`.
  - ambxst's perpetual Canvas: `modules/components/WavyLine.qml`.
  - Caelestia's full-screen shadow: `ContentWindow.qml:189-197`.
  - Caelestia's `nvidia-smi` per tick: `plugin/src/Caelestia/Services/gpu.cpp:330-337`.
