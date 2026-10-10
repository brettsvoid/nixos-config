# Settings: options for the shell's parts

Status: ready-for-human
Type: HITL (which options are worth having)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Settings for the shell's own parts: the bar, dashboard, launcher, notifications, OSD and
lock screen. They go on one page of the settings window (issue 25), or a few.

Caelestia's Panels page and ambxst's Ambxst page are the reference. Between them they
offer dozens of toggles, for example seconds on the clock, how many workspaces show, how
many launcher results show, and the notification timeout.

First list what each part could sensibly offer, then go through the list with the user.
Build only the options they want. Each option is a value in the settings file that the
part reads instead of a fixed value.

Not wanted: a Hyprland page or a keybind editor like ambxst's. Those settings are
declared in Nix, and editing them live would fight the config.

## Acceptance criteria

- [ ] The user has chosen the options. The list and the choices are recorded here.
- [ ] Each chosen option changes the shell at once and survives a restart.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md
