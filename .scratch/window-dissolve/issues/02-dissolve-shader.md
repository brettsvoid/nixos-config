# Dissolve shader with a glowing edge on window open and close

Status: ready-for-human
Type: HITL (how it looks)

## What to build

Replace the test fade with the real effect. On close, a window dissolves away through
a noise pattern, with a glowing edge where pixels are disappearing. On open it runs in
reverse, so the window assembles itself.

The usual way to write it:

1. Per-pixel noise `n` (fbm or hash noise), offset by the per-window `seed` so no two
   windows dissolve the same way.
2. A threshold that rises with `progress`, widened by the edge width so the edge band
   also clears the window at the end.
3. A pixel is gone once the threshold passes its noise value.
4. Pixels just above the threshold glow, mixing towards an ember colour (orange to
   white).
5. Premultiplied alpha that reaches 0 at `progress = 1`, otherwise the window stays and
   then vanishes in one frame.
6. Open uses `1 - progress`.

The plugin replaces Hyprland's own close animation by default and holds the window's
box still, so the shader owns the whole effect.

## Acceptance criteria

- [ ] Closing a window dissolves it with a glowing edge; opening one reverses it.
- [ ] Two windows closed together dissolve in different patterns.
- [ ] No hard pop at the start or end of either animation.
- [ ] Length, edge width, noise scale and glow colour are easy to tune in one place, and
      you are happy with them.
- [ ] Holding a key that opens and closes windows quickly causes no stutter on the
      desktop.

## Blocked by

- window-dissolve/01-load-hyprwindowshade.md

## Comments

**2026-10-09:** First version written, kitty only (scope is issue 03).

- `window-dissolve/dissolve-close.glsl` (0.6 s) and `dissolve-open.glsl` (0.45 s, the
  same effect with the threshold reversed). Both compile as GLSL ES 3.20 (glslang).
- Four-octave value noise in window-local pixels (`window_rect` and `surface_size`, so
  the pattern does not stretch across the monitor-sized close snapshot), offset by
  `seed`; a threshold sweep with a soft cut and an ember band from crimson to hot white.
- No `// @overlay`: a dissolve drives its own alpha, so it takes the plugin's default
  (window held still, neighbours slide in over the same 0.6 s).
- Tuning knobs (`CELL`, `EDGE`, `SOFT`, the two ember colours, `@duration`) are at the
  top of each file and apply on the next open or close, with no rebuild.

**2026-10-09:** Reported: the neighbours' reflow plays visibly behind the dissolving
window and looks strange. The plugin retimes the reflow by copying `windowsMove` with
only the speed changed (`makeRetimedMoveConfig` in `Hooks.cpp`), so holding the tile
until the dissolve ends is not configurable; a C++ patch could give that copy a
hold-then-move bezier. Trying the no-code route first: `// @overlay` in
dissolve-close (duration 0.4 to match windowsOut) plus `windowsOut ... popin 80%`, set
live with `hyprctl keyword` (not yet in the Nix config; a reload reverts it).

**2026-10-09:** Recorded open and close in slow motion (grim frames, animations at 2 s).

- Overlay mode with `windowsOut ... popin 80%`: the text shrank with Hyprland's popin
  but the burn pattern stayed at the window's full size. Dropped overlay mode.
- dissolve-close now shrinks itself (to `SCALE_END` 0.8, ease-out) in the plugin's
  default mode, sampling the snapshot through the shrunken rect; the pattern shrinks
  with the window. Neighbours still slide in underneath over `@duration`.
- Open with `windowsIn ... popin 80%` (Hyprland's own) scales correctly: the pattern
  grows with the window. Set live; not yet in the Nix config.
- Open question: in the close frames the burnt holes look solid black where the
  neighbour should show through. Low-resolution frames; needs a look at normal size.
- Slow-motion settings still live: `@duration 2.0` in both shaders and
  windowsIn/windowsOut/fadeIn/fadeOut/windowsMove at speed 20 via `hyprctl keyword`.

**2026-10-09:** Direction from the user: the burn is liked, but the final look should be
"ninja-like" and without the ember edge. Candidates: the burn with `GLOW = 0.0` (now a
single setting in both shaders), or a smoke effect (tracked in 04). Keep `GLOW = 1.0`
while testing, because the edge makes the effect easy to see.

**2026-10-09:** The holes are see-through (confirmed by the user; the black in the frames
was the dark wallpaper). Fixed bright blobs flashing at the end of an open: the clamped
noise stretch made plateaus at exactly 0 and 1, so whole patches changed on one frame;
now a tanh stretch. Reported: on an empty workspace the window seems to pop in slightly
from the right, then closes into the centre. Not reproduced in a slow-motion recording
on DP-1 (ws 3): the open box was centred from the first visible frame. Waiting on details.

**2026-10-09:** The tanh stretch (k = 5) made the close look worse, and the close paused
before burning. Measured the noise in Python (float32 replica of the shader's fbm):
mean 0.499, sd 0.1335, and the clamped stretch leaves under 1% of pixels on each
plateau. The pause came from the sweep: with the threshold starting at -EDGE, only 2% of
the window burnt in the first tenth of the close. Both shaders now remap through the
noise's own normal CDF (measured flat: 9-11% per tenth) and sweep 0 → 1, so the burn
advances at a steady rate (11, 22, 32 … 100% per tenth); the ember band fades in over
the first 8% of a close and out over the last 8% of an open. Open slowed to 5 s
(`@duration 5.0`, windowsIn/fadeIn speed 50) to look for the reported offset.

**2026-10-09:** Closing during the open paused the close: the open reveals the highest
noise values first and the close burnt the lowest first, so a half-open window's last
frame (high values only) spent the first half of the close losing pixels nobody could
see. The close now burns the highest values first too.

Open offset ("grows from a point to the right", DP-1, Super+Q): measured, not
reproduced. 5 s open on an empty ws 3, frames diffed against the empty frame (bar area
excluded): the box is centred at x 1305 (final window centre 1306) from the first
measurable frame (927 ms, 82% width) and grows symmetrically; top and bottom centred
too. Hyprland 0.56.2 calls `layoutTarget()->recalc()` before `animateIn()` in
`Window.cpp`, so popin centres on the final tile. Before ~900 ms the window is too faint
to measure. Next step if it persists: a 60 fps recording of the user's own Super+Q.

**2026-10-09:** Open offset found and fixed (confirmed by the user). Not the window box:
measured centred in every capture, including a 60 fps wf-recorder capture of the user's
own Super+Q. The burn *pattern* slid left: for a live window `surface_size` is the
animated draw box (`elem->m_data.box.size()` in the plugin's Hooks.cpp), so noise in
pixels from the box's corner moved with the growing box's left edge (both halves of the
window shifted left by 13–17 px on screen per 0.28 s). Both shaders now measure noise
from the window's centre in units of its height (`CELLS` = 20 across the height), which
popin's even scaling leaves stable; after the fix the halves move apart (pattern grows
with the window). Open and close compute the same noise for the same spot.

Settled for now: open 0.4 s with `windowsIn ... popin 80%` (now in the module), close
0.5 s with the shader's own shrink to 80%, plugin default (non-overlay) mode, `GLOW` 1.0
for testing. Not yet checked: two windows closing together; rapid open/close stutter.

**2026-10-09:** Popin now 85% and the close 0.3 s. The user reports rapid open/close
sometimes smears the burn into straight lines; parked at the user's request. Not
reproduced in a 60 fps recording of three scripted patterns on ws 3 (close 0.05/0.15/
0.25 s after map; three opened 0.15 s apart then closed 0.1 s apart; four open-then-close
in a row, each opening while the last still closed): every frame showed the normal blob
pattern.

A lead for it, found while testing smoke (issue 04): kitty maps with a 1x1
`wp_single_pixel_buffer` placeholder stretched over the window by a viewport, and
attaches its first real frame up to ~0.2 s later (WAYLAND_DEBUG). The plugin renders
every shader offscreen at the *buffer's* size (`runIntermediateStages`, Hooks.cpp) and
Hyprland stretches the result over the window box, so during the placeholder the shader
shades one pixel. The burn hides this (that pixel stays transparent until its noise
value comes up, then the window shows kitty's flat background), but any buffer much
smaller than the box, or a different shape, would stretch the burn pattern. If the smear
comes back, record which buffers kitty attaches around it. The shelved smoke open
(issue 04) draws nothing while `textureSize(tex, 0)` is 1x1; dissolve-open.glsl could
take the same guard. Also measured: `surface_size` is sane from the first frame (diagnostic shader
painting it into the window), and `seed` is always 0..1 (splitmix of the window pointer).

**2026-10-09:** Look settled: `GLOW = 0.0` in both shaders, a plain burn, chosen by the
user over the glowing edge and over a first smoke attempt (shelved, issue 04). The ember
code stays behind the `GLOW` constant. Still open here: two windows closing together.
