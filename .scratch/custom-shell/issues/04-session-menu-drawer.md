# First drawer: session menu growing out of the frame

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop with stand-ins for `session-exit` and
`hyprlock` first on PATH (they only logged their arguments).
- The pattern: `frame/Drawer.qml` grows a panel out of any edge of the frame. Its box is
  a `FrameShape` shape, its hit area joins the window's input mask, and its content sits
  in a Loader that is active only while it shows, clipped to the inside of the frame.
  Closed, the box waits a fillet's width behind the frame's inner edge, because the
  fillet union blends any two edges closer than that; coming out, it raises a bump that
  becomes the panel. `services/Drawers.qml` holds which drawer is open and on which
  screen (the focused one). FrameWindow takes the keyboard (`OnDemand`) and a
  `HyprlandFocusGrab` while one is open.
- Motion: the PRD's cubic-bezier curves were Caelestia's, not the spec's. androidx's
  `ExpressiveMotionTokens` define Material 3 Expressive motion as springs (damping
  ratio, stiffness): fast/default/slow spatial 0.6/800, 0.8/380, 0.8/200, effects 1/3800,
  1/1600, 1/800. `components/Spring.qml` steps the exact spring solution each frame,
  keeps its velocity when the target flips mid-way, and stops once settled. Corners
  (`ShapeTokens`: 4, 8, 12, 16, 20, 28, 32, 48), a 4 px spacing grid and the type scale
  (`TypeScaleTokens`) are in `Theme.qml`; the bar keeps its own 13/12 px sizes.
- Keys: `$mod, ESCAPE` binds `global, custom-shell:session` on both hosts, next to
  Caelestia's bind on the desktop. Hyprland runs every matching bind
  (KeybindManager.cpp collects them all), so whichever shell is running answers. With
  the bind added at runtime, Super+Escape from a virtual keyboard (wtype) opened and
  closed the drawer.
- Checked: Down, Down, Enter ran `session-exit reboot`; Down, Enter ran `logout`; Up
  (wraps), keypad Enter ran `poweroff`; clicking Lock ran `hyprlock`; hovering moves the
  highlight. Escape, the shortcut again, and a click outside all close it. The click
  outside is consumed by the focus grab (wev saw only `enter`); the next click goes
  through. Closed, a click where it opens reaches the window. A 60 fps recording shows
  the frame bulging, then the panel coming out joined by fillets, and the reverse. A
  temporary log showed the menu is not created at start, is created on open, survives
  the close motion and is destroyed once it settles.
- Not done unattended: actually logging out, restarting or shutting down. They run the
  same `session-exit` commands Caelestia's menu runs today.
