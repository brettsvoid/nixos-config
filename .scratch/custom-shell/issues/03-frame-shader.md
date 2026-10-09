# Frame shader: border and bar as one shape, with a built-in shadow

Status: ready-for-agent
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
