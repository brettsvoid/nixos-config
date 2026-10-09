# Wallpaper on the background layer, with the theme generated from it

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

The shell draws the wallpaper itself, in a window on the background layer of each
screen, and the theme follows it. Today Caelestia (desktop) and ambxst (laptop) own the
wallpaper, and the custom shell's theme reads ambxst's wallpaper cache.

- The current wallpaper's path is kept in the shell's own state, not in another shell's
  cache.
- Changing it (for now through an IPC call or command; the picker is the next issue)
  crossfades to the new image and runs the existing matugen step, so the frame and every
  drawer recolour.
- Images are decoded at screen size, not at their full resolution.
- On first login with no saved wallpaper, use a default from `~/Pictures/Wallpapers`.

## Acceptance criteria

- [ ] Each screen shows the wallpaper behind all windows.
- [ ] Setting a new wallpaper crossfades and recolours the shell within a second or two.
- [ ] The choice survives a logout and a rebuild.
- [ ] Nothing reads ambxst's or Caelestia's wallpaper state any more.
- [ ] Memory use for a 4K wallpaper is in line with one screen-sized image per screen.

## Blocked by

- .scratch/custom-shell/issues/02-shell-skeleton.md
