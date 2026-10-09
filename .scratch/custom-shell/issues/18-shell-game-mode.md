# In game mode the shell steps aside

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

When game mode turns on, the shell gives back everything it can. When it turns off, the
shell comes back as it was.

- Close any open drawers and unload their content.
- Stop every poller and helper program (stats, visualiser, clipboard UI) that is not
  essential.
- Drop the frame's thickness to nothing and stop drawing it, or keep only a minimal bar,
  whichever costs less (measure).
- Hold back notification pop-ups (keep them in the history), except critical ones.
- Switch off the window dissolve, if it is installed, so games and their launchers are
  never shaded.
- Show a small game mode indicator wherever the bar remains, or in the history once
  game mode ends.

## Acceptance criteria

- [ ] Turning game mode on closes drawers, stops helper processes and hides the frame
      within a second.
- [ ] With game mode on, the shell causes no GPU work while idle (measure on
      brett-desktop with a game running and MangoHud showing frame times).
- [ ] Normal notifications are held back and appear in the history; critical ones still
      show.
- [ ] Turning game mode off restores the frame, the bar and the previous state.
- [ ] The dissolve is off while game mode is on (if installed).

## Blocked by

- .scratch/custom-shell/issues/02-shell-skeleton.md
- .scratch/custom-shell/issues/17-game-mode-toggle.md
