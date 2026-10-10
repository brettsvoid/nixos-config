# Settings window and settings file

Status: done
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

- [x] The keybind, the session menu and the dashboard button all open the window. Opening
      it again brings it forward rather than opening a second one.
- [x] Changing the font, rounding, frame thickness or animation speed changes the shell at
      once. The change is still there after `toggle-shell custom` restarts the shell.
- [x] Wallpaper, scheme and light/dark changed here show in the dashboard's Wallpaper
      tab, and the other way round.
- [x] A hand edit of `settings.json` applies without a restart. A missing or invalid
      file gives the defaults, and the shell still starts.
- [x] With the window closed, settings start no timers and no processes.

## Blocked by

None - can start immediately.

## Comments

**2026-10-10:** Done in fc9e432. It is not live until the next `nix-rebuild` and
`toggle-shell custom`: it was tested from the working tree with qs-dev.

- **Keybind:** Super+I, as on Windows, was free. The cheatsheet reads `hyprctl binds`,
  so the bind's description puts it there.
- **Where:** `settings/` (window and pages), `config/Settings.qml` (the store, which
  imports nothing else from the shell so Theme can read it) and `services/Windows.qml`
  (open or closed, and the page shown).
- **Decisions:**
  - Settings are keyed `section.name` and stored nested. Each has a default and a range
    in `schema`; the file holds only what the user changed.
  - Text size, corner rounding and animation speed are scales on Theme's tokens. Speed
    k gives the springs k² times the stiffness and divides durations by k. The bar's
    height does not follow the text size.
  - Any installed font can be chosen. The Nerd Font icons still draw in another font,
    because fontconfig falls back to FiraCode Nerd Font for them; checked with DejaVu
    Sans Mono.
- **Two Quickshell behaviours worked round:**
  - FileView watches the file's directory, and only if that existed when it loaded. A
    file made later by hand was never seen, so the directory is made once and the file
    read again.
  - `loaded` comes after the first reads, so the shell started with the defaults and
    then changed. The store reads `text()` on completion instead; blockLoading makes it
    wait.
- **Checked live**, with a virtual pointer and wtype; see the commit for the list.
- **Not checked:** pressing Super+I itself. Hyprland runs no binds for wtype's virtual
  keyboard (Super+D did nothing either). The global it calls was checked, and the bind is
  in the generated `hyprland.conf`.
- **Left on the desktop:** a runtime copy of the window rule, the same as the one in the
  config, until Hyprland next reloads. `~/.config/custom-shell/` exists, with no
  settings file.
