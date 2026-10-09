# Wallpaper picker drawer

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A drawer for choosing the wallpaper: a grid of thumbnails from `~/Pictures/Wallpapers`
that you can browse with the keyboard or mouse. Choosing one sets it through the
wallpaper issue's mechanism, so the theme follows. Also let the user pick the matugen
scheme variant and light or dark mode, since `generate-theme` already supports both.

- Thumbnails are generated once and cached at thumbnail size.
- New images added to the folder (home-manager links them in) appear without a restart.
- Decide whether it opens from its own keybind, a launcher prefix mode, or a dashboard
  tab, and record why.

## Acceptance criteria

- [ ] The picker shows every image in the folder as a thumbnail and scrolls smoothly.
- [ ] Choosing one changes the wallpaper and the theme.
- [ ] Scheme variant and light/dark can be changed from the picker.
- [ ] An image added to the folder shows up the next time the picker opens.
- [ ] Opening the picker a second time is fast (thumbnails cached).

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md
- .scratch/custom-shell/issues/14-wallpaper-background.md
