# Shell skeleton: full-screen window, reserved edges, plain frame and top bar

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop (DP-1 landscape, DP-2 portrait).
- Layout: `frame/ScreenShell.qml` per screen holds a full-screen `FrameWindow` (Top layer,
  `ExclusionMode.Ignore`, input mask = whole window minus the inside of the frame) and
  four 1 px `EdgeReservation` windows (Bottom layer, empty input mask) that reserve
  32 px at the top and 8 px elsewhere. `bar/BarSegment.qml` (a MultiEffect shadow per
  segment) is gone; it was swept into `a308c2b` by another session's commit.
- Tiling: windows sit at `[2569,33]` 1062x1878 on DP-2, inside the frame, on both
  screens. Reserved is `[8,32,8,8]` (left, top, right, bottom) per screen.
- Click-through, with wev and a virtual pointer (wlrctl): clicks in the middle and 4 px
  from the inner corners reach the window; on the left, right and bottom bands and the
  bar the window gets only `leave`. Clicking workspace dots on DP-2's bar switches DP-2.
- Fullscreen: a Wayland (wev) and an XWayland (xterm) window in fullscreen each close
  exactly the 5 layers on their screen and reserve nothing; the screenshot shows only
  the app. Leaving fullscreen reopens them. Maximise keeps the frame and fits inside it.
- Hotplug: `hyprctl output create headless` gives the new screen its 5 layers and
  `[8,32,8,8]` at once; `output remove` takes them away. No log output.
- Swap: the installed `toggle-shell`, pointed at a store copy of this config, swaps
  Caelestia → custom → Caelestia cleanly (no custom layers or pid file left). The real
  `toggle-shell custom` runs the installed copy, so it needs a rebuild after this is
  committed; `frame/` must be tracked by git for the flake to see it.
- Upstream race found and worked around: Hyprland's `workspacev2` names no monitor, and
  Quickshell gives it to the monitor it last saw focused. Switching DP-2 to a *new*
  workspace while the pointer is on DP-1 sends `focusedmon DP-2`, `focusedmon DP-1`,
  then `workspacev2`, so DP-1 took the workspace (its bar pill moved, and a fullscreen
  window on DP-2 hid DP-1's frame). `shell.qml` now calls `Hyprland.refreshMonitors()`
  50 ms after each `workspacev2`, and `ScreenShell` ignores an active workspace whose
  own monitor is another screen, so a fullscreen window elsewhere cannot unmap this
  screen's frame. Replayed the sequence: DP-1 kept its 5 layers and its pill.
- Not tested: the laptop (it runs ambxst, so the battery read-out is unchanged code), and
  a real game in fullscreen (the xterm test covers the XWayland path Proton uses).
