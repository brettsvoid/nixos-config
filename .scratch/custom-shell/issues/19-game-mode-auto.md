# Game mode turns on by itself when a game starts

Status: ready-for-agent
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
