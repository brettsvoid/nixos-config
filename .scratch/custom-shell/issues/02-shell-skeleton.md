# Shell skeleton: full-screen window, reserved edges, plain frame and top bar

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

The first end-to-end version of the new window layout, still drawn with plain
rectangles. On each screen:

- One full-screen transparent window on the Top layer. Its input mask covers only the
  frame and the bar, so clicks pass straight through the middle to the apps underneath.
- Four 1-pixel windows that reserve the screen edges, so tiled windows sit inside the
  frame: a thin border on the left, right and bottom, and the bar's height at the top.
- A plain frame around the edges and the existing bar content (workspaces, clock,
  battery) along the top.

When a window goes fullscreen on a screen, the frame and bar on that screen get out of
the way: no reserved space, nothing drawn, no input. They come back when it leaves
fullscreen.

It must keep working with `toggle-shell custom` and `qs-dev` on both hosts, alongside
the other shells.

## Acceptance criteria

- [ ] On every screen, tiled windows sit inside the frame and below the bar, with no
      overlap.
- [ ] Clicks anywhere inside the frame reach the app underneath.
- [ ] Workspaces, clock and battery work as they do today.
- [ ] A fullscreen window, including a game, covers the whole screen with nothing drawn
      on top. The shell's windows are never on the Overlay layer.
- [ ] Unplugging or adding a monitor adds or removes the frame for that screen without a
      restart.
- [ ] `toggle-shell custom` and `toggle-shell caelestia` still swap cleanly.
- [ ] Follows the PRD's performance rules (no full-screen offscreen effect).

## Blocked by

None - can start immediately.
