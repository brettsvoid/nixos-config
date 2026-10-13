# Library of window effects, switchable without a rebuild

Status: ready-for-human
Type: AFK

## What to build

A library of open and close effects instead of one hand-written dissolve, plus a
command that switches which effect is active at runtime.

- **Our own effects:** the dissolve from issue 02, the plain fade, and anything else
  written later. First new one: a **smoke** effect for the "ninja" look the user is
  after (the window breaking into drifting dark wisps, like a smoke bomb), with no
  glowing edge. A first attempt is shelved in `.scratch/window-dissolve/shelved/`
  (see the comment below); the burn at `GLOW = 0.0` is the default meanwhile.
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

## Comments

**2026-10-09:** First smoke attempt, shelved: the user tried it beside the burn and
found it "not so great", to be worked on in another session. Files:
`.scratch/window-dissolve/shelved/smoke-{open,close}.glsl` (0.4 s each). The close
breaks the window up along a wispy, swirl-bent edge (the burn's noise with `SOFT` 0.06)
while a light grey cloud (domain-warped fbm scrolling upwards) billows out, rises 0.3
window heights, spreads up to 0.2 past the edges and thins away; the open is the reverse,
with the smoke confined to the window box. They were tested via runtime rules on a
separate kitty class (`hyprctl keyword windowrule "tag +shader_open:..., match:class
^(fx-smoke)$"` plus a temporary `hyprctl keyword bind`), which needs no rebuild and
leaves the real kitty rule alone; `hyprctl reload` drops them. Window tags sit in a
sorted set, so a second `shader_open:` tag on the same window would win by path name
instead.

Learnt on the way, applies to every effect: kitty maps with a 1x1
`wp_single_pixel_buffer` placeholder and the plugin shades at the buffer's size, so an
effect that draws anything at low `progress` paints one stretched pixel over the whole
window until kitty's first real frame (up to ~0.2 s). The smoke open guards with
`textureSize(tex, 0).x <= 1`. Also measured: a colour fit of the veil gave
0.30 grey at ~0.4 alpha where the shader wrote 0.70 smoke, which may mean the plugin's
offscreen path premultiplies a second time; check before tuning any translucent colour.

**2026-10-13:** Built, not yet committed when written. 50 effects: our dissolve, fade
and none, plus 32 from liixini/shaders and 15 from nirimation. liixini's glass-warp is
left out because its upstream files are cut off and do not compile.

- **The library** is the `window-effects` derivation in `window-dissolve.nix`, made by
  `window-dissolve/build-library.py` from the flake inputs `niri-shaders` and
  `nirimation`. It is linked to `~/.local/share/window-effects`.
  - A wrapper turns each niri `open_color`/`close_color` into a HyprWindowShade shader.
    It maps niri's uniforms, applies niri's easing curve or spring to `progress`, and
    sets `@duration` from the niri config. Outside the window it samples transparent.
    An open shows nothing while the texture is kitty's 1x1 placeholder. A close fades
    out over its last 3%, because the plugin requires full transparency at the end.
  - Springs use the closed-form response for any damping ratio. Checked against a
    simulation: within 0.0001.
  - nirimation's `.kdl` files are read with kdl-py, not by hand.
  - Each ported file names its source, revision and licence, and the licences are
    copied beside them. Adding an upstream effect needs no edits: bump the input.
- **Compile check:** every shader is compiled at build time, as GLSL ES 3.20 (glslang)
  and as the picker's preview (qsb). One of ours that fails stops the build. A ported
  one is left out and listed in `excluded.json`.
- **Switching:** run `window-effect open|close <id>`, or `window-effect list` and
  `window-effect status`.
  - The window rules name `~/.local/state/window-effects/{open,close}.glsl`, and the
    command copies the chosen effect over them.
  - The plugin caches a shader by its path and its mtime in whole seconds, so each
    copy's mtime is made later than the last. Symlinks would not work: every store
    file has the same mtime.
  - Activation runs `window-effect refresh`, so a rebuild updates the active effects.
    The choice lives in that state folder, so it survives a logout.
- **"None"** is a pass-through shader. On close it uses `// @overlay`, so Hyprland's
  own animation is all that shows.
- **Checked live** on the fallback output: the screens were off, so I recorded a test
  kitty window with grim. Runtime rules for the test class only.
  - The dissolve played from the state files.
  - roll-drop fell in from the top, tilted, which confirms the orientation.
  - explode's close flashed across the whole screen, as its author intends.
  - smoke broke the window into wisps.
  - none played Hyprland's popin, slide and fade.
  - Switching took effect on the next window, and three switches within two seconds
    got mtimes one second apart.
- **Not done:** our own smoke (shelved, above). liixini's smoke is in the library, so
  try it first.
- **Left for you:** rebuild, then run `hyprctl reload` or log in again, so Hyprland
  takes the new window rules. Then try a few effects with `window-effect open <id>`,
  or from the dashboard's Effects tab (custom-shell 24).
