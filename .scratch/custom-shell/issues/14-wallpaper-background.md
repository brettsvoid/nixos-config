# Wallpaper on the background layer, with the theme generated from it

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop; the theme was put back afterwards
(chisato, neutral, light; colors.json byte-identical).
- State: `~/.local/state/custom-shell/wallpaper.json` (`path`, `scheme`, `mode`), read
  and written by `generate-theme` and watched by `services/Wallpaper.qml`. Paths stay
  as given: the old selection held a resolved store path, which a rebuild leaves stale
  (or garbage-collects); `~/Pictures/Wallpapers/<name>` links survive rebuilds.
- `generate-theme [image] [--scheme] [--mode|--dark|--light]` now parses its options
  first and fills the rest from the saved choice, so `--dark` no longer loses to a
  saved light mode. With no saved choice it migrates the old
  `~/.cache/qs-theme/wallpaper.json` (scheme, mode, image found by name), else picks
  the first image in `~/Pictures/Wallpapers`. It writes the choice before running
  matugen, so the image starts loading while the colours generate. Nothing reads
  ambxst's or Caelestia's state any more; activation runs it only when the theme or
  the choice is missing.
- `frame/WallpaperWindow.qml`: one per screen on the background layer, no input, no
  exclusive zone. Images decode off the main thread at the size that covers the screen
  (`sourceSize`), uncached; a new one fades in over 600 ms, then the old is released.
- Checked: migration kept the image and produced identical colours; switching to
  dan_da_dan_1 was half-faded at +0.6 s and done by ~1 s, with matugen finished at
  +0.5 s; `--dark` / `--light` switched the mode and kept the image; with an empty home,
  the first wallpaper was chosen.
- Memory (RSS of the shell): 467 MB with no wallpaper, 596 MB with one per screen.
  The decoded images are 2560×1440 and 3413×1920 (cover size for the portrait screen),
  41 MB together, the same for a 6400×3600 source as for 3840×2160 ones (597 vs 596
  MB); the rest is presumably the GPU copies as the NVIDIA driver maps them (not
  broken down). Changing wallpapers did not grow it. Decoding only the visible part
  (`sourceClipRect`) would save about 18 MB on the portrait screen.
