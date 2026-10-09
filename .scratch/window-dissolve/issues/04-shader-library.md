# Library of window effects, switchable without a rebuild

Status: ready-for-agent
Type: AFK

## What to build

A library of open and close effects instead of one hand-written dissolve, plus a
command that switches which effect is active at runtime.

- **Our own effects:** the dissolve from issue 02, the plain fade, and anything else
  written later. First new one: a **smoke** effect for the "ninja" look the user is
  after (the window breaking into drifting dark wisps, like a smoke bomb), with no
  glowing edge. Compare it with the burn at `GLOW = 0.0`.
- **Ported effects** from two MIT-licensed niri shader collections:
  - https://github.com/Xansidev/nirimation/tree/main/animations (burn, burn-ashes,
    explode, glitch, pixelate, ribbons, unravel and others, as `.kdl` snippets)
  - https://github.com/liixini/shaders (dissolve, heat-melt, ink-splash, glitch,
    pixelate, directional wipes and more)

  Keep each collection's licence notice with the files taken from it.
- **A niri adapter:** both collections write niri `custom-shader` functions such as
  `vec4 burn_open(vec3 coords_geo, vec3 size_geo)` using `niri_tex`, `niri_geo_to_tex`,
  `niri_clamped_progress` and `niri_random_seed`. Each has a HyprWindowShade
  equivalent (`window_rect` gives the geometry, `progress`, `seed`, `tex`), so one
  wrapper template can turn a niri function into a HyprWindowShade shader, generated at
  build time rather than ported by hand. Check how niri treats coordinates outside the
  window (`coords_geo` beyond 0..1) against the plugin's behaviour: an open shader only
  covers the window, a close shader covers a monitor-sized snapshot.
- **Switching:** a command (for example `window-effect open burn`) changes the active
  open or close effect without a rebuild. One way is to point a stable path that the
  window rules name at a library file, but first check that the plugin recompiles when a
  symlink's target changes (it compares the file's `stat()` mtime). The plugin's own
  dispatchers are the other route.

Lessons from issue 02 that apply to every effect:

- In the plugin's default close mode the window is held still at full size and the
  neighbours slide in underneath. An effect that wants to shrink must do it in the
  shader (the dissolve does). Overlay mode drew the effect at full size while the
  window shrank under it.
- `@duration` in the shader sets the close reflow's length as well.

## Acceptance criteria

- [ ] The library holds our dissolve and fade plus at least five ported effects, each
      with an open and a close variant where the source has both.
- [ ] Ported files carry their source and licence; adding another niri shader needs no
      hand edits.
- [ ] One command switches the open or close effect; the next window uses it with no
      rebuild or reload.
- [ ] The active choice survives a logout.
- [ ] Every library effect compiles (checked at build time, for example with glslang).

## Blocked by

- .scratch/window-dissolve/issues/02-dissolve-shader.md
