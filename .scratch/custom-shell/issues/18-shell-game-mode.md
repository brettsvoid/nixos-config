# In game mode the shell steps aside

Status: done
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

## Comments

**2026-10-10:** Done and tested live on brett-desktop, apart from a measurement with a game
running (see the last points).
- `services/GameMode.qml` watches `$XDG_RUNTIME_DIR/game-mode` (issue 17). The state file
  moved there from `$XDG_RUNTIME_DIR/game-mode/state`: FileView watches a file's folder
  to see it appear, so the folder has to exist from the start.
- While on: open drawers close (their content unloads, which stops shell-stats and the
  media position timer); the frame and bar shrink away as for fullscreen and the edges
  reserve nothing, so a windowed game gets the whole screen (this costs less than a
  minimal bar, which would still redraw for its clock); normal notifications wait in the
  history, critical ones pop up; the bar is hidden, and its clock stops (SystemClock
  `enabled` follows visibility; without that the hidden clock still caused a redraw per
  screen each minute).
- Checked: with the dashboard open on Performance, `game-mode on` closed it, shell-stats
  was gone and both screens reserved `[0,0,0,0]` within a second; a normal notification
  was held, a critical one showed; 0 frames in 65 s across a minute boundary (2 before
  the clock fix); `game-mode off` brought back the frame, bar and `[8,32,8,8]`, and the
  history held what came in meanwhile. A shell started while game mode was on came up
  without the frame.
- Indicator: no bar remains, so game-mode's own "Game mode on/off" notifications are
  it; "off" shows and both land in the history.
- Dissolve: with game mode's `animations:enabled 0`, a kitty window opened in a single
  frame (60 fps recording), so the dissolve does not play while game mode is on. Whether
  to also unload the plugin (its per-frame hooks) is window-dissolve issue 05's
  measurement, which needs a game running.
- Not measured: GPU work with a game running under MangoHud (unattended run, no game).
