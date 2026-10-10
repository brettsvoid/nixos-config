# Starting settings from Nix

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Let the Nix config set the shell's settings, so a fresh install or another host (the
laptop, issue 23) starts with chosen values. The settings window must keep working.

The settings file from issue 25 belongs to the user. Add a home-manager option, for
example `custom-shell.settings`. The shell uses its values wherever the user has not
chosen otherwise:

- **Order:** built-in defaults, then the Nix values, then the user's own choices.
- **Storage:** the Nix values are a separate read-only file that home-manager writes.
  The settings window never writes it.
- **Rebuilds:** a rebuild that changes a Nix value shows in the shell, unless the user
  has changed that setting in the window.
- **Resetting:** the window can reset a setting to the Nix value, or at least show which
  settings the user has changed.

Do not make `settings.json` itself a home-manager file: the window could then not save.
Caelestia's `shell.json` has that problem here.

## Acceptance criteria

- [x] With no `settings.json`, a value set in Nix shows in the shell after `nix-rebuild`.
- [x] Changing that setting in the window overrides the Nix value and survives a restart.
      The Nix file is untouched.
- [x] Resetting the setting in the window returns it to the Nix value.
- [x] A rebuild that changes a Nix value the user has not overridden applies without a
      restart, or the reason it needs one is recorded here.
- [x] Each host can set its own values.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md

## Comments

**2026-10-10:** Done in b30e596. To use it, set values in a host's home-manager config,
for example:

```nix
home-manager.users.brett.local.customShell.settings.appearance = {
  fontFamily = "Inter";
  textScale = 1.1;
};
```

The keys are the ones in `quickshell/config/Settings.qml`'s `schema`. Nothing is set
yet, so both hosts get an empty `{}`.

- **A copy, not a link:** `~/.config/custom-shell/defaults.json` is copied into place
  during activation, not linked by home-manager. Quickshell's file watch follows a link
  to its store file, which never changes. A link swapped with `ln -sfT`, as a rebuild
  does, went unseen. A file renamed into place is seen, so activation installs it read
  only next to the old one and renames it over, and leaves it alone when unchanged.
- **Reset:** the window shows which settings you have changed by their reset button. A
  value from Nix has none.
- **Testing:** a full rebuild was not run, because sudo needs a password. Instead:
  - `extendModules` built each host with a different value: the desktop's file held 10
    and the laptop's 4.
  - The generated activation snippet, run by hand against the working tree's shell,
    passed every criterion: details in the commit. Changing a Nix value applies with no
    restart.
- **One thing to know:** the module's body moved under `config` beside the new option.
  Most of the commit's diff is that indentation, plus comments re-wrapped to 88
  columns.
