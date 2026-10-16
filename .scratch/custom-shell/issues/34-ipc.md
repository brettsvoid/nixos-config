# Shell IPC

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Commands that drive the running shell from scripts and other programs, through
Quickshell's `IpcHandler`: for example `custom-shell drawers toggle launcher`. Caelestia
has about a dozen targets (`modules/Shortcuts.qml` and its services); ambxst has
`ambxst run <command>`. Ideas only. The shell has no handler yet; its global shortcuts
and the launcher's actions call the services this calls too (`Drawers`, `Windows`,
`Lock`, `Notifications`, `Wallpaper`, `GameMode`, `Osd`).

How it works (Quickshell's `src/io/ipchandler.hpp`, `ipccomm.cpp`): each handler has a
unique `target`, and a function is callable only if its arguments and return are typed
(`function open(name: string): string`): `string`, `int`, `bool`, `real`, `color`, or a
`void` return. At most 10 arguments, and the count must match, so none are optional. A
call that runs exits 0. `qs ipc -c custom-shell` finds the shell (checked with
`qs list -c custom-shell`); without a Wayland display, as in a systemd service, it needs
`--any-display`. Gotcha (`docs/quickshell-notes.md`): an argument that starts with `[`
loses its brackets, so a JSON list must start with a space.

## Proposed choices

1. **Targets.** Names, tabs, modes and pages are case-insensitive words.
   - `drawers`: `toggle(name)`, `open(name)`, `openOn(name, screen)`, `close()`,
     `current(): string`, `dashboard(tab)` (changes the tab if it is open), and
     `launcher(mode)` (apps, clipboard, calculator, actions: types the mode's prefix).
     `openOn` serves scripts and qs-test, whose fake Hyprland has no focused monitor.
   - `settings`: `open(page)` ("" for the last), `close()`, `get(key): string` (JSON),
     `set(key, json)` (through `Settings.set` and its schema checks), `reset(key)`.
   - `lock`: `lock()`, `isLocked(): bool`. **No unlock**: only the password unlocks.
   - `notifications`: `clear()`, `getDnd(): bool`, `setDnd(on: bool)`, `toggleDnd()`,
     `count(): int`.
   - `media`: `playPause()`, `next()`, `previous()`, `stop()`, `current(): string`
     (JSON), on the media card's player. The media keys stay on playerctl here; issue 50
     proposes moving them into the shell.
   - `wallpaper`: `set(path)` (refuses a path that is not a file: `generate-theme` would
     quietly take the folder's first image), `random()`, `get(): string`.
   - `theme`: `getMode`, `setMode(mode)`, `toggleMode`, `getScheme`, `setScheme(scheme)`.
   - `gameMode`: `get(): bool`, `set(on: bool)`, `toggle()`, which run `game-mode`.
   - `osd`: `show(kind)`: volume, microphone or brightness.
2. **Errors.** **A function that takes a name or value returns a string: empty when
   done, else `error: unknown drawer "x" (launcher, dashboard, …)`.** Alternative:
   `void`, with a warning in the shell's log. Reason: the mistake shows where it is made.
3. **Where.** **One `Ipc.qml`, made once in `shell.qml`; each function is a line or two
   into a service.** Alternative: each service owns its handler (Caelestia). Reason: the
   whole interface reads in one place.
4. **Wrapper.** **`custom-shell <target> <function> [args]`, a script in
   `custom-shell.nix` running `${qsPkg}/bin/qs ipc -c custom-shell --any-display call`;
   alone, it runs `show`.** It puts a space before an argument that starts with `[`,
   sends an `error:` reply to stderr with exit 1, and drops a done call's empty line.
   Alternative: scripts write the `qs ipc` line. Reason: it hides the gotcha, and a
   refused call no longer exits 0.
5. **Keybinds.** **Today's global shortcuts stay**: `global, custom-shell:<name>` starts
   no process. IPC is in addition. A future bind with an argument may use `exec,
   custom-shell …` (`qs ipc show` took about 35 ms here); `cheatsheet/binds.js` then
   groups it under Shell, not Apps. No new binds here. Alternative: every bind through
   IPC. Reason: a process per key press for nothing.
6. **Not now:** signals (`qs ipc listen`) and properties (`qs ipc prop get`). Later
   issues add their functions to these targets.

Cost: the IPC socket is idle until called. Nothing in game mode.

## Acceptance criteria

- [ ] `custom-shell` lists the targets; each call does what its shortcut or action does.
- [ ] A bad name prints an `error:` line, and the wrapper exits 1.
- [ ] `custom-shell settings set bar.hiddenScreens '["DP-2"]'` works.
- [ ] `custom-shell drawers dashboard performance` opens Performance, or changes to it.
- [ ] `qs-test -- qs ipc -p "$QS_CONFIG" call drawers openOn launcher HEADLESS-1` opens
      the launcher headless.
- [ ] Every keybind works as before. Costs nothing at rest or in game mode.

## Blocked by

- None
