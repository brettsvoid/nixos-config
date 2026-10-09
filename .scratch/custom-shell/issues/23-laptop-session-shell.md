# Same setup on the laptop; retire ambxst

Status: ready-for-human
Type: HITL (switching the laptop)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Give brett-msi-laptop the same desktop as brett-desktop: the custom shell as its session
shell, game mode, screenshots, and the window dissolve. Then remove ambxst: its flake
input (pinned because later versions stutter on NVIDIA external monitors), its NixOS and
home-manager modules, and anything that still reads its files.

The laptop is NVIDIA Optimus. Check the things that differ from the desktop:

- The battery, backlight brightness and Wi-Fi parts of the shell.
- No stutter with an external monitor attached (the reason ambxst was pinned).
- The discrete GPU stays asleep when idle with the shell running.

The dissolve is not tested separately here. If it does not work on the laptop, fall back
to Hyprland's built-in close and open animations on this host.

## Acceptance criteria

- [ ] The laptop logs in to the custom shell with the same keybinds and drawers as the
      desktop.
- [ ] Battery, brightness and Wi-Fi show correctly.
- [ ] Animations are smooth on an external monitor.
- [ ] The discrete GPU stays suspended at idle (runtime power status in sysfs).
- [ ] The dissolve works, or the fallback animation is in place.
- [ ] ambxst's flake input and modules are removed, and the flake builds for both hosts.

## Blocked by

- .scratch/custom-shell/issues/22-desktop-session-shell.md
- .scratch/window-dissolve/issues/03-dissolve-scope.md
