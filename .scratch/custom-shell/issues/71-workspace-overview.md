# Workspace overview

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A drawer showing every workspace as a small picture of its screen, each window at its
place and size. Click a window to go to it, a workspace to switch, or drag a window onto
another workspace to move it. ambxst: `modules/widgets/overview/` (a live
`ScreencopyView` per window while open, a switch to turn previews off; ideas only).

Quickshell's source (checked): `ScreencopyView` takes a `Toplevel` through Hyprland's
`hyprland-toplevel-export-v1`. With `live: false` it captures one frame when the source
is set (`view.cpp`); `captureFrame()` takes another. It imports dmabufs under Vulkan,
which the shell uses. Hyprland renders the window again for every frame it sends
(`ScreenshareFrame.cpp`, `renderWindow`); for a window off screen the code reads as if
it lets its frame callbacks through, so a live preview keeps a hidden app drawing
(untested). `noscreenshare` windows are refused; `ecosystem:enforce_permissions` is 0.

## Proposed choices

1. **Previews: snapshots,** one frame per window as it opens. Alternatives: live while
   open (ambxst); app icons only. Reason: live cost on the 3080 Ti is unmeasured, and
   each hidden app would draw and be rendered again at its own frame rate. A refused
   capture shows the app's icon. `overview.previews`: `"snapshot"` (default), `"live"`,
   `"off"`.
2. **Layout: one overview on the focused screen with every workspace,** one row per
   monitor: 1 to 5 on the G5, 6 to 10 on the Dell (the workspace rules in
   `brett-desktop.nix`, checked). Tiles have their monitor's shape; rows scale to fit.
   QML's default internal drag works inside one window only, so this layout is the one
   that can move a window to the other screen. Alternative: each screen shows its own.
   The scratchpad (`special:magic`) gets a tile while it has windows.
3. **Window places** from `HyprlandToplevel.lastIpcObject` (`at`, `size`), after one
   `Hyprland.refreshToplevels()` on opening: a socket request, not a process.
4. **Opening:** a drawer from the bar's edge, like the dashboard ("overview" in
   `Drawers`). Super+Tab (free, checked with `hyprctl binds`) as
   `global, custom-shell:overview`, like Super+D; also a launcher action. Escape or a
   click outside closes it.
5. **Actions:** click a window, `focuswindow address:0x…`, and close. Click a tile's
   empty part, `workspace <id>`, and close. Drop a window on a tile,
   `movetoworkspacesilent <id>, address:0x…`, and stay open. Middle click a window,
   `closewindow address:0x…`. The current workspace has the primary outline.
6. **Game mode:** it closes as game mode starts (`Drawers.close()`). Opened in game
   mode, it shows icons, so nothing (the game included) is captured.
7. **Frame shapes:** the shader takes 8 and all 8 are in use; issue 67's change (pass
   only the drawers that show) frees a slot. Whichever issue comes first makes it.
8. **Settings** on a new "Desktop" page, which issues 72 to 74 can share. **Cost:**
   nothing while closed (the content sits in the drawer's Loader); on opening, one
   socket request and one capture per window.

## Acceptance criteria

- [ ] Super+Tab opens it with all ten workspaces and the windows in place; Super+Tab or
      Escape closes it.
- [ ] Every window shows a snapshot, including on hidden workspaces.
- [ ] Dragging a window from 2 onto 7 moves it to the Dell's workspace 7; clicking a
      window on the other screen focuses it there.
- [ ] Closed, no `ScreencopyView` exists.
- [ ] Record GPU use with `"live"` and `"snapshot"` and a video in a window (`nvidia-smi`
      once, in a terminal).
- [ ] Costs nothing in game mode: no captures.

## Blocked by

- None
