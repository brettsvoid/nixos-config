# Lock screen

Status: done
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

- [x] The session menu's Lock and the lock keybind lock every screen; the right password
      unlocks; a wrong one shows an error.
- [x] Suspending and resuming shows the lock screen straight away, with no flash of the
      desktop.
- [x] Killing the shell while locked leaves the session locked, and the written recovery
      steps get you back in.
- [x] Plugging a monitor in while locked shows the lock on it too.
- [x] Nothing in the lock screen animates while idle.

## Blocked by

- .scratch/custom-shell/issues/03-frame-shader.md

## Comments

**2026-10-10:** Built (`quickshell/lock`, PAM service `custom-shell`, hypridle config,
Super+L, `lock-recover`, docs/lock-screen.md); not switched yet. Decisions:

- **PAM:** its own service, not hyprlock's, which would vanish with hyprlock and leave
  no password able to unlock. The shell refuses to lock (and says so in a
  notification) while `/etc/pam.d/custom-shell` is missing.
- **Sleep:** hypridle, which NixOS already turns on with programs.hyprlock and which
  failed at every login for want of a config. `before_sleep_cmd = loginctl
  lock-session`, `inhibit_sleep = 3`: it holds sleep until Hyprland reports the session
  locked, which Hyprland sends only once every output has drawn a lock frame
  (SessionLockManager.cpp, 0.56.2). Caelestia and ambxst lock on logind's Lock signal
  themselves, so Super+L and sleep work under all three shells.
- **`misc:allow_session_lock_restore`: off.** With it on, any client can take over a
  live lock, not just a dead one (onNewSessionLock only refuses while the old lock is
  unconfirmed). `lock-recover` turns it on for two seconds. The lockdead screen's own
  advice (`hyprctl eval 'hl.clear_crashed_lockscreen()'`) needs the Lua config.

Checked on brett-desktop with a lock-only copy of the shell, then the full one, using
test PAM files (pam_permit / pam_deny) and a 25 s auto-unlock as a safety net:

- Both screens lock: blurred wallpaper, clock, date, field; the screen with the keyboard
  shows the field's border. Typing shows dots; Enter unlocks (pam_permit).
- Wrong password: red border, "Wrong password", the field swings 23 px, then about 10,
  and settles. Through the real stack (/etc/pam.d/hyprlock, the same as the new file)
  a wrong password answers after 2.3 s; "Checking…" is drawn meanwhile, so nothing
  freezes. The journal logs it as an ordinary pam_unix failure.
- Idle: 135 frames in the first second (the content rising in, two screens), then 0
  frames in the next 13 s (QSG render timing). The clock redraws once a minute.
- Hotplug: DP-2 disabled and enabled again while locked got its own lock surface.
- Session menu Lock, `custom-shell-or lock loginctl lock-session` (the Super+L
  command), and `loginctl lock-session` run from the user manager (as hypridle's
  before_sleep_cmd is) through a hand-started hypridle with this config: each locked.
  hypridle held a sleep inhibitor, dropped it once locked, and took it again on unlock.
- Media card shows while something plays (Firefox), with working controls.
- Killing the shell (SIGTERM) while locked: Hyprland's lockdead screen, session still
  locked (Quickshell destroys the lock without unlocking). Recovery as `lock-recover`
  does it (start the shell, restore on, lock, restore off) put the lock back, and
  typing unlocked.
- PAM file missing: no lock, an error in the log and a critical notification.

Found while testing:

- Quickshell 0.3.0's `WlSessionLock.locked` does not notify when it turns on (only on
  unlock), so nothing can bind to it; `Lock.locked` follows `secure` instead.
- When Hyprland refuses a lock because another client holds one, Quickshell exits with
  a fatal Wayland error ("invalid object 45"), reproduced twice. Only matters with two
  lockers at once; noted in docs/lock-screen.md.
- Once, the session was left on the lockdead screen for about a minute (the safety
  timer bound to `locked`, which never fired) and was recovered with the steps above.
- One test step typed "pw" + Enter into the focused terminal when a lock did not
  engage (`custom-shell-or` is not installed until the switch); typing now waits for
  the lock to be confirmed.

Still to do, after switching (needs you):

- [x] Under the custom shell (`toggle-shell custom`): Super+L and the session menu
      lock; your real password unlocks; a wrong one shows the error.
- [x] Suspend and resume (`systemctl suspend`): the lock is up at once, no desktop.
      Checked by Brett 2026-10-10. The keyboard does not wake this desktop, the power
      button does; fine for this setup.
- [x] Recovery from a text console: lock with Super+L, Ctrl+Alt+F2, log in,
      `kill $(cat /tmp/custom-shell.pid)` (the crash), `lock-recover`, Ctrl+Alt+F1 when
      it says, unlock.

**2026-10-10, recovery from tty2 failed:** `lock-recover` reported success, but the
restarted shell died about 3 s later with `wl_display#1: error 0: invalid object 465`
(Qt exits on a protocol error, so Quickshell's own log had nothing; the shell's stderr,
then sent to /dev/null, had it), and the "lockscreen app died" screen stayed. Twice with
tty2 active. The shell started from tty2 without locking ran normally; the same lock
steps run once tty1 was active locked, and the password unlocked. Hyprland stops
rendering while its VT is inactive and sets its monitors up again when it comes back
(Compositor.cpp, Renderer.cpp); why the lock request breaks is not known.

`lock-recover` now starts the shell, says to press Ctrl+Alt+F1, waits until Hyprland's
VT (its logind session's VTNr) is showing, waits 2 s, then locks, and leaves the result
on tty2. `toggle-shell custom` sends the shell's output to
`$XDG_RUNTIME_DIR/custom-shell.log` instead of /dev/null. docs/lock-screen.md updated.
Needs the test again.
- Not tested: the laptop (issue 23). hypridle gets this config there too, under ambxst,
  which locks on logind's Lock signal like Caelestia does.

**2026-10-10, after the switch (Brett, hypridle's log for the times):** locked and
unlocked with the real password at 11:01; suspend at 11:03:33 went Lock signal, locked
within the second, then sleep; woke 11:03:58, unlocked 11:04:06. Recovery with the new
`lock-recover` from tty2: the lock screen replaced the lockdead one a few seconds after
Ctrl+Alt+F1 (locked 11:32:11, unlocked 11:32:52); `misc:allow_session_lock_restore`
back to 0 afterwards. A wrong password was not tried against `/etc/pam.d/custom-shell`
itself; it was against /etc/pam.d/hyprlock, which has the same auth lines. The laptop is
left to issue 23.
