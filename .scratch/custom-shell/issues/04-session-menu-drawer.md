# First drawer: session menu growing out of the frame

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

The first drawer, and with it the pattern every later drawer follows. Super+Escape
opens a session menu (lock, log out, reboot, shut down) that grows out of the frame.
Its background is one of the shapes in the frame shader, so it melts into the border.
While it moves, the input mask follows it.

This issue also sets up the shared design values that later drawers reuse: motion
curves and durations (Material 3 Expressive, values in the PRD, checked against the
spec), the rounding and spacing scale, and the type scale.

Behaviour:

- Opens on the keybind (a Hyprland global shortcut owned by the shell) and closes on the
  keybind again, on Escape, or on a click outside it.
- Takes keyboard focus while open, and the arrow keys and Enter work.
- Content is only loaded while it shows.
- Log out, reboot and shut down go through the existing `session-exit` command, so open
  apps are saved for the next login as they are today. Lock runs hyprlock (installed
  system-wide) until the shell's own lock screen exists.

## Acceptance criteria

- [ ] Super+Escape opens and closes the menu with a smooth grow-out-of-the-frame motion.
- [ ] The drawer and frame look like one shape at every point of the animation.
- [ ] Escape and an outside click both close it; clicks elsewhere still pass through
      when it is closed.
- [ ] All four actions work, and log out/reboot/shut down restore apps at the next
      login.
- [ ] Motion, rounding, spacing and type values live in one place that later drawers can
      import.
- [ ] With the drawer closed, nothing of it is loaded.

## Blocked by

- .scratch/custom-shell/issues/03-frame-shader.md
