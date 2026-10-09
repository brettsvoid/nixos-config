# Volume and brightness on-screen display

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

When the output volume, mute state or screen brightness changes, a small display slides
out of the frame showing the new level, then hides itself after a moment.

- It reacts to the value changing from any source (media keys, the mixer, another app),
  not only to the keybinds. Volume comes from Quickshell's PipeWire module.
- Brightness applies to the laptop's backlight. On the desktop, only show it if external
  monitor brightness is controlled from the shell (out of scope here).
- Microphone mute gets its own state if it is easy to add.

## Acceptance criteria

- [ ] Volume keys change the volume and show the display with the new level.
- [ ] Changing the volume from a mixer app also shows it.
- [ ] Mute shows a muted state.
- [ ] On the laptop, brightness keys show the brightness level.
- [ ] The display hides by itself and takes no input while hidden.
- [ ] Holding a volume key gives a smooth display, not a restart of the animation on
      each step.

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md
