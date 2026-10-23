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
- [x] A bad name prints an `error:` line, and the wrapper exits 1.
- [x] `custom-shell settings set bar.hiddenScreens '["DP-2"]'` works.
- [x] `custom-shell drawers dashboard performance` opens Performance, or changes to it.
- [x] `qs-test -- qs ipc -p "$QS_CONFIG" call drawers openOn launcher HEADLESS-1` opens
      the launcher headless.
- [ ] Every keybind works as before. Costs nothing at rest or in game mode.

## Blocked by

- None

## Comments

**2026-10-19:** All six choices approved as proposed, on the review page.

**2026-10-22:** Built as approved (commit `custom-shell: IPC, and a custom-shell command
to call it`). Status is ready-for-human: the wrapper and the keybinds have not met the
running desktop shell, which needs the rebuild first.

Checked headless with `qs-test`, with the wrapper pointed at the test shell by path
(`qs ipc -c custom-shell` finds an instance by the path it started from, so it cannot
see qs-test's shell; `qs list -c custom-shell` and `qs ipc -c custom-shell show` do reach
the live one, which has no targets yet):

- Bad names and values print `error: ...` and exit 1:
  `custom-shell drawers toggle nope` gives `error: unknown drawer "nope" (session,
  launcher, cheatsheet, notifications, dashboard)`; `settings set bar.edge '"middle"'`
  gives `error: bar.edge takes one of top, bottom, left, right`; an unknown setting,
  screen, dashboard tab, launcher mode, settings page, mode, scheme and OSD kind are
  refused the same way; `wallpaper set` refuses a folder, a missing file and a relative
  path.
- `custom-shell settings set bar.hiddenScreens '["DP-2"]'` exits 0, `settings get` gives
  `["DP-2"]` and the test's `settings.json` holds it. `reset` removes it again.
- `qs-test -- qs ipc -p "$QS_CONFIG" call drawers openOn launcher HEADLESS-1` exits 0
  and `drawers current` then gives `launcher`.
- `drawers dashboard performance`: with the dashboard closed it opens on Performance, and
  open it changes tab (logged `Overview`, `Performance`, `Wallpaper` in one run). A
  tab the settings hide is shown too. `drawers launcher clipboard|calculator|actions|apps`
  opens the launcher in that mode or changes it while open. `settings open "window
  effects"` opened the settings window on that page, `open Audio` changed it, `open ""`
  left it. These used a copy of the shell whose `Drawers.focusedScreen()` returns
  HEADLESS-1, because qs-test's fake Hyprland has no focused monitor.
- Every other target: `lock lock` then `isLocked` gave `true` (headless sway);
  `notifications setDnd true`, `toggleDnd`, `getDnd`, and `count` after a `notify-send`
  gave 1 and after `clear` 0; `media` against a silent mpv with mpv-mpris: `playPause`
  paused and resumed it and `current` gave `{"player":"mpv","playing":false,"title":
  "Test tone",...}`; `wallpaper set`, `random`, `theme setMode|toggleMode|setScheme` and
  `gameMode set|toggle` ran the stubs (`generate-theme ...`, `game-mode on|toggle` in
  the calls log); `osd show volume` showed the OSD (logged in a copy).
- The cheatsheet's grouping (`binds.js`, run with node): `exec, custom-shell drawers ...`
  and bare `custom-shell` go under Shell; `custom-shell-or ...` and `kitty` stay under
  Apps.
- At rest: RSS of the headless shell was 183.0 MB with the change and 182.9 MB without,
  16 threads each, 0 or 1 CPU tick in 5 s. Nothing runs in game mode: no timer or
  process was added.
- `nix develop -c pre-commit run --all-files` passes and brett-desktop's home builds
  (`qs-test --check` included).

Two things found, both in `docs/quickshell-notes.md`: `qs ipc call osd show volume`
fails because `show` is read as the sibling subcommand (the wrapper calls with `--`),
and `qs ipc call` prints its own refusals (unknown target, wrong argument count) on
stdout and exits 0, so the wrapper also treats those as errors.

Beyond the approved text, and why:

- `wallpaper set` takes a full path only (the shell's own working folder would resolve
  a relative one).
- `theme setScheme` takes the name with or without `scheme-`, as `getScheme` gives it.
- Functions that take only a bool (`setDnd`, `gameMode set`) still return a string, as
  choice 2 says for any value; a bad bool is qs's own error ("Unable to parse
  argument"), which the wrapper also exits 1 on. qs reads only `true`, `false` or an
  integer, so `off` is refused.
- Settings take JSON, so a string needs its quotes: `settings set bar.edge '"left"'`.
- `Players.active` (`services/Players.qml`) holds the media card's rule, so the card and
  the `media` target share it. Issue 50 plans a singleton of that name and can grow
  this one.
- The first `media` call after the shell starts finds no player until something has
  read MPRIS (the dashboard or lock screen), because Quickshell reads the players on
  first use. Reading them at start would add a D-Bus watch at rest, so it is left lazy.

Still to check, on the desktop after the rebuild (the shell restarts by itself):

1. `custom-shell` lists nine targets: `drawers`, `settings`, `lock`, `notifications`,
   `media`, `wallpaper`, `theme`, `gameMode`, `osd`.
2. `custom-shell drawers toggle dashboard` opens the dashboard on the focused screen and
   a second run closes it. With it closed, `custom-shell drawers dashboard performance`
   opens it on Performance; run it again with `wallpaper` while it is open and the tab
   changes. `custom-shell drawers launcher actions` opens the launcher with `>` typed.
3. `custom-shell drawers toggle nope; echo $?` prints the `error:` line and 1.
4. `custom-shell settings set bar.hiddenScreens '["DP-2"]'` hides the bar on DP-2 (use a
   screen name from `hyprctl monitors`); `custom-shell settings reset bar.hiddenScreens`
   brings it back.
5. The keybinds as before: Super+R, Super+/, Super+D, Super+N, Super+Escape, Super+I, and
   the brightness keys on the laptop (they show the OSD).
6. `custom-shell theme toggleMode` switches light and dark, as the launcher's actions do;
   `custom-shell osd show volume` shows the volume OSD.
7. Not checked at all: `gameMode`, `wallpaper set` and `lock lock` for real. Say if you
   want those run on the desktop; `lock lock` needs your password.

When 1 to 5 hold, set the status to done.

**2026-10-23 (later):** Checked by the user on the desktop: `custom-shell` lists the targets. It lists ten, this issue's nine plus issue 53's `pomodoro`. The keybinds were not reported on yet.
