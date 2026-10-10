# Game mode turns on by itself when a game starts

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Feral GameMode is already enabled, and a game starts it when it opts in (for example
`gamemoderun %command%` in Steam's launch options). Use its start and end scripts to turn the game mode from the
toggle issue on and off, so nobody has to remember the key.

- A game starting turns game mode on; the last game ending turns it off.
- If the user had already turned game mode on by hand, a game ending leaves it on.
- Document how a game opts in (for example `gamemoderun %command%` in Steam's launch
  options), and check whether the Nolvus launcher and the rofi game library start
  GameMode.

## Acceptance criteria

- [ ] Starting a game through GameMode turns game mode on; quitting it turns it off.
- [ ] Two games running at once: game mode stays on until both have exited.
- [ ] A manual game mode toggle is respected when a game ends.
- [ ] The opt-in step for Steam games is written down in the module's comments.

## Blocked by

- .scratch/custom-shell/issues/17-game-mode-toggle.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop with `gamemoderun sleep` as the game and
the hooks in a temporary `~/.config/gamemode.ini` (removed afterwards, since
home-manager will own it).
- GameMode (1.8.2 source) reads `$XDG_CONFIG_HOME/gamemode.ini` as well as
  `/etc/gamemode.ini`, reloads it when it changes, allows `[custom]` from the user file
  (only `[gpu]` is refused there), and runs every `start` script when the first game
  registers and every `end` script when the last one leaves, through `/bin/sh -c` with
  a 10 s timeout. So desktop-game-mode writes the user file; no NixOS change.
- `game-mode auto-on` turns game mode on only if it is off, and marks it
  (`$XDG_RUNTIME_DIR/game-mode.auto`); `auto-off` only turns off a marked one. Manual
  on/off/toggle clear the mark. GameMode runs the scripts with a bare PATH and maybe
  without the session's Hyprland signature, so the script adds `/run/current-system/sw/bin`
  (where hyprctl is) and finds the newest instance itself. The first test failed with
  exit 127 for exactly that; afterwards it also worked from `env -i`.
- Checked: one game turned it on (marked) and its end turned it off, options restored;
  with two games it stayed on until both had exited; turned on by hand first, a game
  ending left it on.
- Opt-in, written in the module: Steam launch options `gamemoderun %command%`. The rofi
  game library starts games through Steam (`steam://rungameid`), so they pick that up;
  nothing in the repo runs `gamemoderun` today, and the Nolvus setup does not mention it.
- Found on the way (not changed here): GameMode's own CPU tuning fails on the desktop.
  Its helpers go through pkexec, which the polkit rule (`gamemode.rules`) only allows
  for the `gamemode` group, and the user is not in it ("Not authorized"; "Failed to
  update cpu governor policy", "split_lock_mitigate"). Add `gamemode` to the user's
  extraGroups in profile-gaming.
