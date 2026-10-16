# A transparency setting

Status: ready-for-human
Type: HITL (how much transparency still reads well is a judgement of looks)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A slider that makes the frame, bar and drawers see-through, with the wallpaper blurred
behind them. Caelestia has it (`services/Colours.qml`: off by default, base 0.85, inner
layers 0.4, and a Hyprland `layerrule` for blur and `ignore_alpha` set at runtime);
ideas only.

- Today everything is opaque. The frame, bar and every drawer (pop-ups and the OSD too)
  are one shape drawn by `shaders/frame.frag`, filled with `Theme.frameColor`, which is
  `Theme.base` (matugen's background). The shadow outside it is black at up to 30%.
  Cards inside drawers use `surfaceContainer` and similar, also opaque.
- Quickshell has `BackgroundEffect.blurRegion` (ext-background-effect-v1), and
  Hyprland 0.56 honours it on a layer surface without a `layerrule`, only inside the
  region (read in both sources). The region can be the frame window's mask region.
- Hyprland's costs, read in its source (`render/ElementRenderer.cpp`, `OpenGL.cpp`):
  - **Live blur** blurs the part of the surface that changed, before clipping to the
    region. The frame window covers the whole screen, so any change anywhere (a video
    in a window) gets a blur pass, though only the frame shows it.
  - **xray** blur uses Hyprland's cached blur of the Background and Bottom layers
    instead. Without an xray layer Hyprland refreshes that cache, when those layers
    change, only while a tiled see-through window shows; with one, on every change.
  - Neither is measured on the RTX 3080 Ti yet.

## Proposed choices

1. **One opacity for the frame, bar and drawers; cards stay opaque.** Alternative: a
   second, gentler value for the cards (Caelestia's "layers"). Reason: text stays on
   solid ground.
2. **Blur: `BackgroundEffect` over the frame, bar and open drawers, with the layer set to
   xray** (`hyprctl keyword` for namespace `custom-shell-frame`, set again on
   `configreloaded` as `theme/WindowBorders.qml` does). Only the wallpaper is ever under
   the bar and frame band, so xray looks right there; an open drawer shows the blurred
   wallpaper, not the windows behind it. Alternatives: live blur (drawers show the
   windows behind, at a blur pass per changed area all the time); no blur.
3. **While issue 74's bars or issue 78's video play, the blur goes off** (empty region,
   xray set off). Each of their frames would otherwise refresh the cache. Reason:
   they play only while the desktop shows, with drawers closed.
4. **Settings** (Appearance page, "Text and shape"): `appearance.opacity` (1, 0.5–1,
   step 0.05; 1 is today) and `appearance.blur` (on; used only below 1). The blur region
   is the mask's region, which leaves out the shadow and the fillets where a drawer
   meets the frame: check those corners look right.
5. **At an opacity of 1 nothing changes:** no blur region, no xray rule, no cost.
6. **Not included:** the lock screen (it blurs the wallpaper itself) and the settings
   window (an ordinary window, under Hyprland's own opacity rules).
7. **Cost:** no process or timer. In game mode and fullscreen the frame shrinks to
   nothing, so the region is empty and Hyprland blurs nothing.

## Acceptance criteria

- [ ] At 1 the shell looks and costs as today: no blur region and no xray rule.
- [ ] Below 1 the frame, bar and drawers show the blurred wallpaper; the inside of the
      frame is not blurred.
- [ ] GPU use (`nvidia-smi` sampled during a test) with a drawer open over a playing
      video, at 1 and at 0.8, is noted here.
- [ ] It costs nothing in game mode.
- [ ] Each setting applies at once and survives a restart and a Hyprland reload.
- [ ] You choose a default opacity after trying 0.95, 0.85 and 0.75 on two wallpapers.

## Blocked by

- None
