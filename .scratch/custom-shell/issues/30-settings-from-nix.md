# Starting settings from Nix

Status: ready-for-agent
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

- [ ] With no `settings.json`, a value set in Nix shows in the shell after `nix-rebuild`.
- [ ] Changing that setting in the window overrides the Nix value and survives a restart.
      The Nix file is untouched.
- [ ] Resetting the setting in the window returns it to the Nix value.
- [ ] A rebuild that changes a Nix value the user has not overridden applies without a
      restart, or the reason it needs one is recorded here.
- [ ] Each host can set its own values.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md
