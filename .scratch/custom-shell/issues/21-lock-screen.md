# Lock screen

Status: ready-for-human
Type: HITL (a broken lock either locks you out or fails to lock)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A lock screen in the shell's style, using the Wayland session-lock protocol
(Quickshell's session lock) and PAM for the password. It replaces Caelestia's lock and
hyprlock as the thing the session menu, the lock keybind and sleep use.

- Shows on every screen: the wallpaper (blurred or dimmed), a clock, and the password
  field; media controls if something is playing.
- Wrong passwords show an error without a long freeze; PAM's own delay is fine.
- The screen locks before the machine sleeps, so it is never briefly visible on wake.

Safety comes first:

- If the shell crashes while locked, the session must stay locked (the protocol
  guarantees this) and there must be a known way back in. Hyprland has
  `misc:allow_session_lock_restore` for restarting a crashed lock client; decide whether
  to enable it and write the recovery steps down.
- Test the recovery from a TTY before making this the default lock.

## Acceptance criteria

- [ ] The session menu's Lock and the lock keybind lock every screen; the right password
      unlocks; a wrong one shows an error.
- [ ] Suspending and resuming shows the lock screen straight away, with no flash of the
      desktop.
- [ ] Killing the shell while locked leaves the session locked, and the written recovery
      steps get you back in.
- [ ] Plugging a monitor in while locked shows the lock on it too.
- [ ] Nothing in the lock screen animates while idle.

## Blocked by

- .scratch/custom-shell/issues/03-frame-shader.md
