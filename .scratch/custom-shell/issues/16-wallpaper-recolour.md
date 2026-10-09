# Fixed palettes and recolouring the wallpaper to match

Status: ready-for-human
Type: HITL (how it looks)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Today the theme always comes from the wallpaper. Add the other direction: pick a fixed
palette (Crimson Ronin first, MIT, already a flake input and used by the game library)
as the theme source, and optionally recolour any wallpaper to that palette with a
shader, so wallpaper and shell always match.

- The theme source is either "from wallpaper" (matugen, as now) or a named fixed palette.
- Recolouring maps each wallpaper pixel to the palette (ambxst does this with a
  palette-texture shader; write our own) with a strength setting, and can be switched
  off.
- It runs once per wallpaper or palette change, not every frame.
- The picker gets the palette choice and the recolour switch.

## Acceptance criteria

- [ ] Choosing Crimson Ronin themes the shell with its colours regardless of the
      wallpaper.
- [ ] With recolour on, any wallpaper is shown in the palette's colours; the strength
      setting blends towards the original.
- [ ] Switching back to "from wallpaper" restores today's behaviour.
- [ ] No per-frame cost once the recoloured wallpaper is shown.
- [ ] You are happy with how two or three very different wallpapers look recoloured.

## Blocked by

- .scratch/custom-shell/issues/15-wallpaper-picker.md
