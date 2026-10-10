# Game mode toggle for Hyprland (works without the shell)

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop.
- `modules/home/desktop/game-mode.nix` (new home module `desktop-game-mode`, on both
  hosts): `game-mode on|off|toggle|status`, bound to Super+Shift+G; Caelestia's bind
  for its own game mode is removed.
- On: saves each option's live value (`hyprctl getoption -j`: an int, a float or a
  custom string such as "8 8 8 8") as `keyword` lines, then applies everything in one
  `hyprctl --batch`. Off: replays the saved lines in one batch. Not `hyprctl reload`: a
  reload re-reads the whole config, which also drops binds other programs add at
  runtime (Caelestia adds Caps Lock and Num Lock binds) and re-applies monitor rules.
  If nothing was saved (the runtime dir was cleared), off falls back to a reload.
- State: `$XDG_RUNTIME_DIR/game-mode/state` holds "on" or "off" (written by rename), for
  a shell to watch; other programs change it by running `game-mode`. A notification
  confirms each change (replacing the last one). Feral GameMode is left to
  profile-gaming.
- Tearing, from Hyprland's `isTearingBlocked`/`canBeTorn`: the master switch
  (`allow_tearing`, which game mode sets), no zoom, a monitor that supports async flips,
  no visible hardware cursor, the window alone and fullscreen on its monitor, and the
  window allowing it: either the app asks (tearing-control protocol) or a window rule
  marks it `immediate`. Game mode adds no such rules; a game that should tear needs its
  own (it trades VRR's smoothness for latency). Documented in the module.
- Checked: on set all eight options and saved their values, including "4 4 4 4" and
  "8 8 8 8"; the notification popped up; off put every option back exactly (a diff of
  all eight against before), as did two toggles more; the number of binds did not
  change. Both hosts' binds evaluate.
