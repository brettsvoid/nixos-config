# Keyboard layout switcher

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Show the keyboard layout in the bar and switch to the next one. Caelestia has a
layout entry and popout in its bar (`modules/bar/popouts/`; ideas only).

What exists (checked):

- One layout only. Nothing in the repo sets `input:kb_layout` (`hyprctl getoption`
  says `us`, not set), and both hosts' NixOS keyboard layout is `us`. Every keyboard
  on the desktop reports `English (US)`. The desktop's keyboard is a ZSA Moonlander,
  whose layers live in its firmware.
- Quickshell's Hyprland module has no keyboard type. `Hyprland.rawEvent` does carry
  Hyprland's `activelayout` event (`<keyboard>,<layout name>`). Switching is a hyprctl
  command (`switchxkblayout`), not a dispatcher, so `Hyprland.dispatch` cannot send it.
- `hyprctl -j devices` gives each keyboard's `layout` list and `active_layout_index`.
  The desktop has 12 keyboard devices (the mouse, the headset, power buttons).
  `switchxkblayout current` takes the first one Hyprland marks active, so `all` is
  the safe target.

## Proposed choices

1. **Which layouts.** **Close this issue unless you name a second layout.** With one
   layout a switcher has nothing to switch. Alternative: name them (for example
   `us,gb`, or a variant such as `us(intl)` for accents). They go in `hyprland.nix`
   as `input.kb_layout` (and `kb_variant`), for both hosts.
2. **The switch key.** **Super+Space: `bindd = "$mod, SPACE, Next keyboard layout,
   exec, hyprctl switchxkblayout all next"` in `hyprland.nix`.** It shows in the
   cheatsheet, and works under any shell. Caelestia's launcher binds Super+Space too,
   but only while Caelestia runs, and issue 22 removes it. Alternative: an XKB option
   such as `grp:alt_shift_toggle` in `input.kb_options`, which starts no process but
   does not show in the cheatsheet.
3. **The bar entry.** **A short code (`US`, `GB`) beside the status icons, shown only
   while more than one layout is set. A click switches to the next layout.** Issue 40
   lists a layout entry too: it is built here, and 40 leaves it out. Setting:
   `bar.showKeyboardLayout` (true), on the Bar page. Alternative: a popout listing the
   layouts to pick one (issue 37's popouts).
4. **How it reads and switches.** **Through Hyprland's request socket, with no
   process.** A Quickshell.Io `Socket` on `Hyprland.requestSocketPath` asks for
   `j/devices` at start, after `configreloaded`, and 100 ms after the last
   `activelayout` event (one switch sends an event per keyboard). The code is the
   `active_layout_index` entry of `layout`. A click writes
   `switchxkblayout all next` to the same socket. Alternative: `hyprctl` processes,
   which would start one per layout event (PRD rule 2).
5. **Cost.** No timers and no processes. Events come only when the layout changes.
   Nothing runs in game mode.

## Acceptance criteria

- [ ] With one layout, the bar shows nothing new.
- [ ] With two, the bar shows the code. Super+Space and a click both switch, and the
      code follows.
- [ ] A rebuild that changes the layouts updates the entry without a shell restart.
- [ ] No process starts for a layout event. It costs nothing in game mode.

## Blocked by

- None
