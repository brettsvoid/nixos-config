# Custom shell: notes for working on it

Facts about the custom shell (`modules/home/desktop/quickshell`, wired up by
`modules/home/desktop/custom-shell.nix`) that were found the hard way and that no config
file states.

## Testing

`qs-test` runs the shell headless and apart from the desktop. It uses a headless sway
with its own bus and folders, stubs for the commands that change the desktop, and a fake
Hyprland. Run `qs-test --help` for how to drive it. Building a host's home runs
`qs-test --check` on the installed config, so a QML error fails the rebuild.

- With offscreen Qt (`QT_QPA_PLATFORM=offscreen`), `PanelWindow` is unavailable, along
  with every per-screen window built on it. That is why `qs-test` uses a headless sway.
- Quickshell's IPC socket sits under `$XDG_RUNTIME_DIR`. A long runtime path overflows
  the 108-byte socket path limit, so keep test runtime folders short (`/tmp/...`).
- Quickshell reloads when a file's content changes, not on `touch`. Just after a
  reload, `qs ipc` answers "Not ready to accept queries yet".
- `qs-test` renders in software (`QT_QUICK_BACKEND=software`), which draws no
  `ShaderEffect` or `MultiEffect`: the frame, the lock screen's blur and the effect
  previews do not show in its screenshots. Check those on the desktop.
- The fake Hyprland has no focused monitor, so drawers, pop-ups and the OSD get no
  screen: a test has to set `Drawers.screen`, `Notifications.screen` or `Osd.screen`
  to `HEADLESS-1`. A drawer opened again before it has finished closing keeps its
  content, so `Component.onCompleted` does not run again; wait about a second.
- Per-screen settings are keyed by Hyprland's description of a screen, and the fake
  Hyprland reports no monitors. `qs-test -s 2 -m monitors.json` gives two outputs and
  answers with that file (`hyprctl monitors -j`'s shape), so they have descriptions.
- `qs ipc call` reads an argument that starts with `[` as its own list syntax and drops
  the brackets. Start a JSON list with a space.
- `wlrctl pointer` makes a new pointer for each call and removes it at once, so a
  hover never lasts. Hover needs a virtual pointer that stays connected
  (wlr-virtual-pointer, for example from pywayland). A click 0.4 s after the move into
  a window was lost; after 1 s it landed. sway's own `seat - cursor press` did nothing
  there.
- `wtype` loses the first key of each call while the keymap changes; `wtype -s 300`
  waits first. With it, typing into a field works (`wtype -s 300 "wifi"`), as do
  Escape and Return (`-k Escape`) and chords (`-M ctrl -k f -m ctrl`), each in its own
  call. Every call also bounces the window's keyboard focus (Qt logs "Ignoring
  unexpected wl_keyboard.leave"), so `activeFocus` flickers: keep UI state in a property
  that a key sets, not in `activeFocus`, or a test sees it flip.
- `qs-test --check` (and so the build) also fails on the shell's own `console.warn` and
  `console.error`, logged as `WARN qml:` with no file name. `shell.qml` uses this to
  check that every setting has a search entry.
- `GameMode.on` needs the state file to say `on`; an empty file is off.
- `GameMode.loaded` is false until the state file has been read: `on` starts false, so
  code that must not run in game mode waits for `loaded` (`services/LockKeys.qml`).
- Testing PipeWire: `qs-test`'s runtime folder has no PipeWire, and Quickshell only looks
  for a server that starts later when `QS_PIPEWIRE_IMMEDIATE_RECONNECT=1` is set. A private
  server (`pipewire` with `PIPEWIRE_CONFIG_DIR` and `XDG_RUNTIME_DIR` set to the test
  folder) needs a metadata object named `default` (`{ factory = metadata args = {
  metadata.name = default } }` in `context.objects`) before `pw-metadata -n default 0
  default.audio.source ...` gives Quickshell a default node. With no session manager,
  adapter nodes and streams make no ports until `adapter.auto-port-config = { mode = dsp
  monitor = false position = preserve }` is in their properties (a `pw-record -P` JSON
  argument for a stream), and `pw-link` then links them. A `support.null-audio-sink` with
  `media.class = Audio/Source` is the default source Quickshell sees (`PwNodeType.AudioSource`).
- A recording shows in Quickshell's link groups as a source device (`type ===
  PwNodeType.AudioSource`) linked to a stream with type `PwNodeType.AudioInStream`, state
  `PwLinkState.Active` once the link is tracked with a `PwObjectTracker`. Captures of a
  sink's monitor (the visualiser) link from the sink node instead. `PwNodeLinkTracker`
  returns from its whole update on a link to a monitor stream, so it is not used.
- A real Hyprland can run apart from the desktop, for a plugin or a config: nested in a
  headless mutter (`mutter --headless --wayland --no-x11 --virtual-monitor 1920x1080`,
  on its own D-Bus), with Mesa's EGL (`__EGL_VENDOR_LIBRARY_FILENAMES` set to
  `50_mesa.json`) so both render on the Intel iGPU. sway 1.12 and Weston 16 are too old
  as parents: Hyprland's Wayland backend asks for `xdg_wm_base` 6 and `wl_compositor` 6.
  - Its Wayland output never became a monitor there. `hyprctl output create headless`
    gives one that renders, and windows open on it.
  - Give it its own `XDG_RUNTIME_DIR`, `HYPRLAND_NO_SD_VARS=1` (or it imports its
    display and signature into systemd and D-Bus), and a `LIBSEAT_BACKEND` that libseat
    does not know (or its DRM backend tries the seat and every input device first).
  - Its exec lines run for real: stub them, or they start the session's apps again.
- A second headless output in the nested Hyprland (`hyprctl output create headless` again)
  takes `hyprctl keyword monitor <name>,1920x1080,0x0,1,transform,1` for a 1080x1920 one; a
  rule that changes the mode itself (`1080x1920@60`) was ignored. Test windows: `kitty
  --class x -e sh -c '...'` reading titles from a fifo and printing `\033]2;<title>\007`
  changes the title live, but not with `--title`, which fixes it.
- `hyprctl dispatch exec kitty --class x` reads `--class` as its own flag: quote the whole
  command after `exec`.
- A virtual keyboard (wtype, `zwp_virtual_keyboard_v1`) does not toggle Caps Lock or Num Lock
  in Hyprland's state: the client has to send `modifiers` with the lock bit itself. A
  `wtype` keyboard is also gone again before a `hyprctl devices -j` that follows its key.
  A persistent client that sends the key and then the modifiers drives the real chain: a
  `global` bind's shortcut is pressed and released with the key, also with Shift or Num
  Lock on, and `devices -j` then shows `capsLock` and `numLock` per keyboard.

## QML and Quickshell gotchas

- `qs ipc call` reads the function name `show` as its own subcommand (`osd show` fails
  with "argument was not expected"): write `qs ipc call -- osd show volume`. It prints
  its own refusals (unknown target or function, a wrong argument count or type) on
  stdout and exits 0, and only a missing instance exits non-zero; the `custom-shell`
  command turns them into exit 1.
- `qs ipc -c custom-shell` finds the instance by the config path as it was started, not
  through a link, so under `qs-test` use `qs ipc -p "$QS_CONFIG"`.
- `FileView.loaded` only means the path exists, so it is true for a folder. A read that
  fails gives `loadFailed` (`FileViewError.NotAFile` for a folder), also from
  `waitForJob()` (`Wallpaper.isFile`).
- Setting several `JsonAdapter` properties one after another loses values:
  `onAdapterUpdated: writeAdapter()` starts a write for the first, and the second's write
  waits for it and then reads the first's file back over the properties, so the property
  just set reads its old value. That pattern suits one property set at a time. For
  several, keep the live state in plain properties and save them as one `var`
  (`services/Pomodoro.qml`).
- `transient` is a reserved word in QML: name the property something else
  (`NotificationEntry.isTransient`).
- A `JsonAdapter` list property is not a JS array: `Array.isArray` is false. Use
  `Array.from(list)` before `map` or `filter`, or a restart saves an empty list.
- JavaScript's `sort` in QML is not stable. Break ties by index where the order
  matters (`ActionsMode`).
- A reload emits the live notifications through `onNotification` again. Track them
  by id, or the history doubles.
- `DesktopEntries.applications` is empty on first access. `shell.qml` reads it at
  start.
- Quickshell keys the state folder on a hash of the config path, which changes with
  every rebuild. `shell.qml`'s `ShellId` and `StateDir` pragmas fix it at
  `~/.local/state/custom-shell`.
- Home-manager's files are symlinks: `find` needs `-L` to see them.
- qalc needs `-t -s 'unicode off'` for plain output (otherwise its minus sign is
  Unicode). It writes its config under `$HOME`.
- A `Repeater` or `ListView` whose model is a JS array makes every delegate again on
  each change, so timers in them start again and animations are cut short. Use a
  `ScriptModel` (`notifications/Popups.qml`), or bind the model to a string key that
  changes only when the items do (`bar/Workspaces.qml`).
- Qt 6.11's `Grid` adds a spacing's width at the end when it has more columns than
  visible items. Use a `GridLayout`, which leaves hidden items out, or exactly as many
  columns as items (`bar/Tray.qml`).
- Anchors switched by bindings (`anchors.left: vertical ? undefined : parent.left`)
  can leave an item where it was. Place it with `x` and `y` instead (`bar/Bar.qml`).
- An `on<Property>Changed` handler also runs while the object is made, before
  `Component.onCompleted`. Guard writes that must wait (`dashboard/Dashboard.qml`).
- An `IdleMonitor` whose `timeout` changes after it is made never reports idle again.
  Make a new one for each value with an `Instantiator` (`lock/Idle.qml`). The same
  pattern restarts a `Process` with new arguments (`dashboard/PerformanceTab.qml`).
- Quickshell's `Hyprland.activeToplevel` ignores `activewindowv2` with an empty address
  (focus on an empty workspace, by `connection.cpp`), so it keeps the old window until
  another takes focus or that one closes. A `HyprlandToplevel`'s `wayland` handle, and so
  `appId`, arrives after the toplevel itself. A binding that kept a window because its
  `workspace` still matched held a closed one (null) afterwards, as nothing changed again:
  check membership in `workspace.toplevels.values` (`services/ActiveWindows.qml`).

## Hyprland and GTK

- Hyprland reloads its whole config when any file it sources changes (an inotify
  watch on each). A reload drops runtime `hyprctl keyword` changes, game mode's
  included. For values that change at runtime, use `hyprctl keyword`, and set them
  again on the `configreloaded` event (`theme/WindowBorders.qml`).
- GTK 3 and GTK 4 read `~/.config/gtk-{3,4}.0/gtk.css` once, when an app starts.
  Changing the theme name doesn't make them read it again. libadwaita 1.9 still takes
  its colours from the `@define-color` names there. Light/dark (dconf's
  `color-scheme`) applies to open apps at once.
- Hyprland's `dpms off` is not undone by input (`misc:mouse_move_enables_dpms` and
  `misc:key_press_enables_dpms` are off by default, and this config leaves them off).
  Whatever turned the screens off has to turn them on (`lock/Idle.qml`).

## Upstream source

Read upstream code to confirm a behaviour before relying on it. Caelestia (GPL-3) and
ambxst (AGPL-3) are for ideas only, never copied (`.scratch/custom-shell/PRD.md`).

- Flake inputs (`quickshell`, `caelestia-shell`, `ambxst`):
  `nix flake archive --json | jq -r '.inputs["quickshell"].path'`.
- Anything in nixpkgs (gtk3, libadwaita, adw-gtk3):
  `nix build --no-link --print-out-paths .#nixosConfigurations.brett-desktop.pkgs.libadwaita.src`.
  Some sources are tarballs to unpack.
- Hyprland:
  `nix build --no-link --print-out-paths .#nixosConfigurations.brett-desktop.config.programs.hyprland.package.src`.
