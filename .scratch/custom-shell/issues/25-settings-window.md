# Settings window and settings file

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A settings window for the shell, as Caelestia and ambxst have, and the settings file
behind it. This issue builds the window, the file and the first page (Appearance). The
other pages are issues 26 to 29.

- **The window.** A normal floating window, not a drawer from the frame; both reference
  shells use one. It opens from a keybind (pick a free one), a "Settings" entry in the
  session menu and a button in the dashboard. Opening it again brings the open window
  forward. The list of pages is on the left, the page on the right.
- **The file.** A `Settings` singleton holds the shell's preferences and saves them to
  `~/.config/custom-shell/settings.json`, a plain file that home-manager does not manage.
  - Do not let home-manager manage it. Caelestia's `shell.json` is a home-manager link
    into the Nix store here, so Caelestia's settings window cannot save.
  - Changes apply as they are made, with no restart. A hand edit of the file applies
    too.
  - A missing or broken file falls back to the defaults and does not stop the shell
    starting.
  - Leave room for Nix to supply starting values later (issue 30). It helps if the file
    holds only what the user changed.
- **The Appearance page.**
  - Wallpaper, scheme variant and light/dark, through the existing `Wallpaper` service.
    The dashboard's Wallpaper tab keeps its controls, and both show the same state.
  - Font family and size, corner rounding, frame thickness and animation speed. `Theme`
    reads these instead of its fixed values. Choose sensible ranges.
- **Nothing runs while the window is closed** (performance rule 3). Pages load only while
  the window is open.
- Add the keybind to the cheatsheet.

## Acceptance criteria

- [ ] The keybind, the session menu and the dashboard button all open the window. Opening
      it again brings it forward rather than opening a second one.
- [ ] Changing the font, rounding, frame thickness or animation speed changes the shell at
      once. The change is still there after `toggle-shell custom` restarts the shell.
- [ ] Wallpaper, scheme and light/dark changed here show in the dashboard's Wallpaper
      tab, and the other way round.
- [ ] A hand edit of `settings.json` applies without a restart. A missing or invalid
      file gives the defaults, and the shell still starts.
- [ ] With the window closed, settings start no timers and no processes.

## Blocked by

None - can start immediately.
