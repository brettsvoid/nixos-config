# Commands typed in long-lived terminals talk to a Hyprland that has gone

Status: done
Type: AFK

## What happened

The herdr server is a daemon (its parent is PID 1) and outlives Hyprland. On
brett-desktop it started on 2026-10-09 at 13:49 under one Hyprland instance. It was
still running after Hyprland restarted at 21:12, and again at 10:59 on 2026-10-10.
Every pane it opens gets the environment the server started with. So in every pane,
`HYPRLAND_INSTANCE_SIGNATURE` named the first instance, long dead. herdr has no option
to refresh a pane's environment: `herdr --default-config` has none.

In such a pane, `hyprctl` fails with "Couldn't connect to …/.socket.sock", and anything
started from the pane inherits the stale value. On 2026-10-10, `toggle-shell custom`
started the custom shell that way. The shell reached Wayland, so its windows and global
shortcuts worked, but not Hyprland's socket. It had no focused monitor, so Super+Escape
and Super+/ opened nothing.

Already handled:

- `toggle-shell` and `qs-dev` keep the inherited signature only if `hyprctl instances`
  lists it, and otherwise take the newest live instance (commit f4a3637).
- `lock-recover` uses `--instance 0`.
- Hyprland's binds and `exec-once` run with Hyprland's own environment.

Still affected: anything else run from an old pane. That includes `hyprctl` itself and
`game-mode`, whose fallback only covers an unset signature, not a stale one.

## What to build

Make a shell in a long-lived terminal follow the running Hyprland, so commands typed
after a Hyprland restart reach it.

One way: a zsh `precmd` hook, Linux only. When the signature does not name a live
instance, it points `HYPRLAND_INSTANCE_SIGNATURE` and `WAYLAND_DISPLAY` at the newest
one in `hyprctl instances -j`.

The prompt must stay cheap. Testing for `$XDG_RUNTIME_DIR/hypr/$sig/.socket.sock` costs
nothing, and the dead instances here had no `.socket.sock` left. But a hard-killed
Hyprland may leave a stale socket file, so confirm before trusting the test. Only run
`hyprctl instances` when the test fails.

Processes already running, such as an open Claude Code session, keep their environment;
only new commands are fixed. Give `game-mode` the same live-instance check as
`toggle-shell` (`liveHyprland` in `custom-shell.nix`), or share one helper.

## Acceptance criteria

- [x] In a zsh started with a dead instance's signature, the next prompt has the live
      instance's signature and `WAYLAND_DISPLAY`, and `hyprctl version` answers.
- [x] A shell whose signature is live is left alone. So is a shell where no Hyprland
      runs: a text console, SSH, macOS. The prompt is not noticeably slower.
- [x] `game-mode status` reaches the running Hyprland when started with a stale
      signature.
- [x] The scripts in the repo that call `hyprctl` from a terminal were checked for the
      same assumption.

## Blocked by

None - can start immediately.

## Related

- custom-shell issue 22: when the custom shell becomes the session's shell, start it
  from Hyprland (`exec-once`, or a user unit after Hyprland's environment import), never
  from a terminal.

## Comments

**2026-10-10:** Done in 458f41d. Not live until the next `nix-rebuild`: sudo needs a
password, so it was tested from the built generation.

- **One helper.** `liveHyprland` moved from custom-shell.nix to `flake.lib`
  (hyprland.nix), and toggle-shell, qs-dev, game-mode, the zsh hook and the laptop's
  resume service all use it.
- **The prompt's check.** It does not test for `.socket.sock`. `strace` shows how
  `hyprctl instances` decides an instance is live: it reads `hyprland.lock` (pid, then
  Wayland socket) and calls `kill(pid, 0)`. The hook does the same with zsh builtins.
  The dead instances here had no `.socket.sock` left, but a hard-killed Hyprland would
  leave one, and its pid would still be dead.
- **Results**, with the built hook in zsh:
  - Started with this terminal's dead signature, the live one was set before the first
    prompt, and `hyprctl version` answered.
  - A live signature and an unset one were left alone, with no hyprctl call.
  - A fake hard-killed instance (`hyprland.lock` with a dead pid, plus `.socket.sock`)
    was treated as dead, and WAYLAND_DISPLAY changed with the signature.
  - It costs 19 µs a prompt, and about 8 ms when the instance is gone.
  - The Darwin config has no hook (only the Linux hosts import desktop-hyprland).
- **game-mode.** `status` only reads `$XDG_RUNTIME_DIR/game-mode`. The real test was
  `on` and `off` from the stale terminal, which turned animations off and on again in
  the running Hyprland. Game mode was off before and after.
- **Scripts checked:**
  - Fixed: the laptop's `hyprland-resume-monitors` took the first directory in
    `/run/user/1000/hypr`, which `ls` sorts oldest first, so after a Hyprland restart it
    named a dead instance. Its lookup, run in an empty environment here, now picks the
    live one. Its monitor commands were not run (laptop only).
  - Already safe: `exec-once` and bind commands (Hyprland's own environment; hyprland,
    window-dissolve, ambxst, xwayland-primary-odyssey, hypr-cheatsheet, Thunar's Quick
    Look). `thunar-quick-look-keys`, a user service, restarted with the current Hyprland
    and has its signature. `lock-recover` uses `--instance 0`.
