# Game mode toggle for Hyprland (works without the shell)

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A `game-mode` command (on, off, toggle, status) that frees the compositor's resources
for gaming, bound to Super+Shift+G. Today that key calls Caelestia's game mode, which
sets these Hyprland options at runtime and runs `hyprctl reload` to undo them:
animations off, shadows off, blur off, inner and outer gaps 0, border 1, rounding 0,
tearing allowed. Do the same without Caelestia, so it works under any shell, and move
the keybind to it now.

- Apply the changes in one batch so there is no flicker of half-applied state.
- Turning it off restores the configured values. Check what a config reload also resets
  (for example options other tools set at runtime) and pick the safer way back.
- Expose the on/off state somewhere a shell can read and watch (for the bar indicator
  and the next issue), and let other programs change it (the auto-trigger issue).
- Check what tearing needs beyond the global switch (Hyprland's per-window `immediate`
  rule) and decide whether game mode sets it for games.
- Feral GameMode (already enabled) handles CPU-side tuning; do not duplicate it.

## Acceptance criteria

- [ ] Super+Shift+G toggles game mode on and off under Caelestia, ambxst or the custom
      shell.
- [ ] With it on, animations, blur, shadows, gaps and rounding are off; with it off,
      everything is exactly as configured.
- [ ] `game-mode status` reports the state, and the state can be watched for changes.
- [ ] A notification or on-screen hint confirms each change.
- [ ] Tearing behaviour is documented in the command's comments: what it does and what
      it needs.

## Blocked by

None - can start immediately.
