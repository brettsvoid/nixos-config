# Frame shader: border and bar as one shape, with a built-in shadow

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Replace the plain frame with the Caelestia-style look. The frame and the bar are drawn
as one shape by one fragment shader:

- Each part is a rounded box measured as a signed distance. The parts are joined with a
  smooth minimum, so where the bar meets the frame there is a concave fillet instead of
  a hard corner.
- The inner edge of the frame is rounded.
- Edges are anti-aliased from the distance field.
- The drop shadow is computed in the same pass from the same distance, not with a
  `MultiEffect` or layer over the full-screen item.
- The shader takes a small, fixed number of shapes (enough for the frame, the bar and a
  handful of open drawers), so later issues can add drawer shapes without changing how
  the shader is fed.

Write the shader ourselves (see the PRD's licence decision). The build compiles it with
Qt's shader tools as part of the Nix build, so nothing is compiled at runtime.

When the screen goes fullscreen, the frame's thickness and rounding animate down to
nothing rather than vanishing.

## Acceptance criteria

- [ ] Frame and bar render as one shape with smooth fillets and a soft shadow, using the
      theme colours.
- [ ] Adjusting thickness, rounding, fillet size or shadow in one place changes the look
      live under `qs-dev`.
- [ ] Changing the wallpaper theme recolours the frame without a restart.
- [ ] The shader is compiled at build time; a shader error fails the build.
- [ ] Idle GPU use with the shell running is no higher than with the plain-rectangle
      skeleton (measure on brett-desktop).
- [ ] The fullscreen transition animates and leaves nothing on screen.

## Blocked by

- .scratch/custom-shell/issues/02-shell-skeleton.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop.
- `shaders/frame.frag` draws the frame as the screen minus a rounded hole whose top runs
  off the screen, and joins up to eight rounded boxes to it (the bar is box 0) with a
  circular fillet union: where two parts meet at a concave corner, the distance follows
  a quarter circle of radius `fillet`. Parts are never blended along parallel edges,
  which is what bulges the edge when a smooth minimum is used everywhere (Caelestia's
  notes describe the same trap). Coverage uses `fwidth`, the shadow is a quadratic
  falloff of the same distance outside the shape. `frame/FrameShape.qml` feeds it from a
  `shapes` list, so a drawer only appends an entry. The input mask subtracts the same
  rounded hole (fillet radius at the top corners, rounding at the bottom).
- Tokens in `Theme.qml`: `frameRounding`, `frameFillet`, `frameShadowSize`,
  `frameShadowColor`, `frameRevealDuration`. Changing rounding to 48 and the shadow to
  40 showed in the running shell after the reload. Quickshell can miss an in-place
  truncate-and-write (`cp`, Python), because it skips the empty-file event; editors that
  save by rename are picked up.
- `generate-theme` light → dark → light recoloured the frame and bar without a reload.
  (`generate-theme --dark` with no wallpaper argument keeps the saved mode; issue 14
  replaces that script.)
- Build: `custom-shell.nix` copies the config and runs `qsb` on `shaders/*.frag|vert`;
  `qs-dev` compiles into the repo (`*.qsb` is ignored). A broken shader fails the build
  with qsb's error.
- Fullscreen: this replaced issue 02's unmapping. Mapping the five windows again took
  about 120 ms each, so the frame came back about a second after the window left
  fullscreen. Now the windows stay mapped and `reveal` goes to 0, which shrinks the
  shape and empties the input mask. Hyprland fades Top-layer surfaces under a fullscreen
  window, and a faded one does not count against `solitary` (Monitor.cpp
  `isSolitaryBlocked`): with vkcube fullscreen on DP-2, `solitaryBlockedBy` is null both
  ways. Recorded at 60 fps: both transitions take about 330 ms and leave only the app;
  a fullscreen wev gets clicks at the screen edges; the shell redraws nothing while the
  window stays fullscreen. The edges stay reserved, so windows behind a fullscreen one
  no longer re-tile.
- GPU, `nvidia-smi` power over 65 s idle: skeleton 51.2 W, shader 51.7 W, 2 redraws each
  (the clock). Redrawing every frame (165 Hz): skeleton 88.3/89.5 W, shader 89.6/89.9 W.
  Utilisation was too noisy at idle clocks to compare.
