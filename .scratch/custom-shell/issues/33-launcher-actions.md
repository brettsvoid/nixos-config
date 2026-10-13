# Launcher actions

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

An actions mode in the launcher, as Caelestia's `>` (gaps list). Typing `>` first lists
things the shell can do, filtered by the rest of the query:

- **Session:** lock, log out, restart, shut down (all as the session menu does them,
  through `session-exit`) and sleep.
- **Shell:** settings, keybinds, notifications and dashboard (each opens its window or
  drawer).
- **Look:** light, dark, a random wallpaper, choosing a wallpaper (the dashboard on its
  Wallpaper tab), and each colour scheme variant.
- **Toggles:** game mode and do not disturb, each named for what it will do.

Choosing an action that opens another drawer must leave that drawer open.

## Acceptance criteria

- [ ] `>` lists the actions, and the rest of the query filters them.
- [ ] Each action does what it says. Test the session ones up to the command they run,
      but don't run it.
- [ ] Choosing the wallpaper action opens the dashboard on the Wallpaper tab.
- [ ] The toggles say whether they will turn the setting on or off.

## Blocked by

- .scratch/custom-shell/issues/05-launcher-drawer.md

## Comments

**2026-10-13:** Built, not yet committed, and tested headless (see issue 31). The
session, theme and game mode commands were replaced by stubs that record their
arguments, so nothing ran for real.

- Each action ran the right command: `session-exit poweroff`, `reboot` and `logout`,
  `systemctl suspend`, `game-mode on`, `generate-theme` with a random image (never the
  current one), `--mode light` and `--scheme scheme-tonal-spot`.
- The do not disturb toggle turns it on and off, and its name follows the state.
- Wallpaper opens the dashboard and asks for its Wallpaper tab.
- **Found on the way:**
  - Qt's JavaScript sort is not stable. Equal matches now keep the list's order by
    index.
  - The wallpapers are home-manager symlinks, so the random pick uses `find -L`.
- The launcher now closes before an action runs, so an action that opens a drawer
  keeps it open.
- **Left for you:** try it in the real launcher, and check that Wallpaper opens on the
  Wallpaper tab.

**2026-10-13:** Checked on screen after the rebuild. It works in the real launcher.
