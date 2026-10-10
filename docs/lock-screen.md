# Lock screen

The custom shell's lock screen (`modules/home/desktop/quickshell/lock`). It covers every
screen, and your login password unlocks it: PAM checks it against
`/etc/pam.d/custom-shell` (`modules/system/nixos/hyprland.nix`).

These lock it:

- Super+L.
- The session menu's Lock (Super+Escape).
- Suspending. hypridle asks logind to lock the session, then holds the sleep back until
  Hyprland reports every screen locked. logind waits at most 5 s.

Under Caelestia or ambxst, Super+L and suspending use that shell's own lock instead.

## If the lock dies or will not take your password

The session stays locked. If the lock screen app has died, Hyprland shows "Oopsie daisy,
it looks like you locked your screen but the lockscreen app died". Its own advice,
`hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`, only works with a Lua
Hyprland config. This config is hyprlang, so the command replies "eval is only supported
with the lua config manager".

1. Press Ctrl+Alt+F2 and log in.
2. Run `lock-recover`. It stops the custom shell if it is still running, starts it
   again, and has it lock.
3. Press Ctrl+Alt+F1 (Hyprland runs on tty1) and type your password.
4. Back on tty2, log out with `exit`.

If `lock-recover` says the shell did not start, end the session from tty2 with
`hyprctl --instance 0 dispatch exit`. You lose unsaved work and get the login screen.

`lock-recover` also works when Caelestia's lock has died: it switches you to the custom
shell, and `toggle-shell caelestia` switches back.

### Why it is not automatic

Hyprland only lets a new lock take over a locked session while
`misc:allow_session_lock_restore` is on. When on, it also lets any program replace a
working lock and unlock the session. It is off normally. `lock-recover` turns it on
for the two seconds it needs, then off again.

## Known limits

- **Two lockers at once:** if another program already holds the lock (hyprlock started
  by hand, say), Hyprland refuses the shell's lock. Quickshell 0.3.0 then exits with a
  Wayland error, so the bar goes too. Start it again with `toggle-shell custom`.
- **PAM file missing:** if `/etc/pam.d/custom-shell` is missing, the shell refuses to
  lock and sends a notification instead. Locking then would leave no way to unlock. It
  only happens when the shell is newer than the system generation.
