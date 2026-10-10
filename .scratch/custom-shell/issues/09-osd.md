# Volume and brightness on-screen display

Status: done
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

## Comments

**2026-10-10:** Done, tested live on brett-desktop (no backlight).
- `services/Osd.qml` decides what shows: it follows the default sink's volume and mute
  and the default source's mute through PipeWire, so any source of change counts, and
  ignores the first second (the shell reading current values). It shows on the focused
  monitor and hides 1.5 s after the last change. The display is a Drawer on the bottom
  edge with `takesFocus: false` and no region in the input mask, so it never takes
  input or focus (a click on it while shown reached wev underneath).
- Brightness: the backlight sends no change events, so the brightness keys also fire
  `global, custom-shell:brightness` (both hosts, beside the existing `brightnessctl`
  binds, which keep working under any shell). The shell then runs
  `brightnessctl --machine-readable --class=backlight info` once, 100 ms later, at most
  every 100 ms while the key is held. Without `--class=backlight`, brightnessctl picks a
  keyboard LED (here `input36::scrolllock`). On the desktop the read fails and nothing
  shows, as intended. The laptop path is untested.
- Checked: `wpctl` volume change (45%), mute (muted glyph, faint bar), microphone mute
  on and off (the headset), all hiding by themselves; no display at start. A loop of 40
  1% steps every 30 ms: PipeWire delivered every step (~40 ms apart), screenshots every
  ~150 ms showed the level climbing 44% to 69% in one open panel, the bar easing
  between levels. (A wf-recorder capture of the same loop froze for a second; the
  shell's own frame count and the screenshots show that was the recorder.) Volume and
  microphone restored to 0.40 and 1.00.
- Not tested: the physical volume keys. wtype's XF86AudioRaiseVolume did not trigger
  Hyprland's bind (Super+Escape from wtype does); the bind runs the same `wpctl
  set-volume` as tested.
