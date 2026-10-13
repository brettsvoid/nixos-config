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

## QML and Quickshell gotchas

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

## Hyprland and GTK

- Hyprland reloads its whole config when any file it sources changes (an inotify
  watch on each). A reload drops runtime `hyprctl keyword` changes, game mode's
  included. For values that change at runtime, use `hyprctl keyword`, and set them
  again on the `configreloaded` event (`theme/WindowBorders.qml`).
- GTK 3 and GTK 4 read `~/.config/gtk-{3,4}.0/gtk.css` once, when an app starts.
  Changing the theme name doesn't make them read it again. libadwaita 1.9 still takes
  its colours from the `@define-color` names there. Light/dark (dconf's
  `color-scheme`) applies to open apps at once.

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
