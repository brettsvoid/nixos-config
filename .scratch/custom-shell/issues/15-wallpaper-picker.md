# Wallpaper picker drawer

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop; the wallpaper and theme were put back
(chisato, neutral, light; colors.json byte-identical).
- Where: a **Wallpaper tab in the dashboard** (Super+D, then Tab). The dashboard
  already loads tabs only while they show; a grid of thumbnails does not fit the
  launcher's one-column list; and it needs no key of its own.
- Thumbnails: `wallpaper-thumbnails` (custom-shell.nix, ImageMagick) makes 384×216
  JPEGs in `~/.cache/custom-shell/wallpaper-thumbnails/<name>.<bytes>.jpg`, only the
  missing ones, each time the tab opens. The tab lists the wallpaper and thumbnail
  folders with FolderListModel, which watches both. Two traps found: on the first run
  the thumbnail folder did not exist when the tab started watching (the script now
  creates it and prints "ready", and the tab only then points at it), and a temporary
  name ending in .jpg hid the last thumbnail (renaming does not change the count the
  tab follows; the temporary file is now `<thumb>.part`).
- The grid shows every image (19), the current one outlined; arrows and Enter, hover
  and click. Pills above set light/dark and the matugen scheme through
  `generate-theme --mode/--scheme`; the dashboard itself recolours.
- Checked: cold, thumbnails filled in as they were made, all 19 within about 4 s;
  reopened, they were there at once. Right, Right, Enter chose dan_da_dan_1; Left,
  Left, Enter went back. Content then Neutral, Dark then Light changed the saved choice.
  The wheel scrolls the grid. A test image added to the folder showed, with its
  thumbnail, at the end of the grid on the next open; it was removed afterwards.
- Fixed in Dashboard: the tab Loader now gives the loaded tab focus, so the grid gets
  the arrow keys.
