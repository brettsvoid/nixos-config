# More bar entries

Status: ready-for-agent
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

New entries in the bar:

- **OS logo** at the start: the NixOS snowflake (Nerd Font `nf-linux-nixos`, U+F313, in
  FiraCode Nerd Font). A click opens the launcher.
- **Power button** at the end. A click opens the session menu.
- **Microphone** beside the volume: mute state; a click toggles mute; scrolling changes
  the input volume.
- **Caps Lock and Num Lock**, each shown only while on.

Caelestia: `modules/bar/components/` (`OsIcon.qml`, `Power.qml`,
`status/LockStatus.qml`). Ideas only. Builds on `bar/StatusIcon.qml` and
`AudioStatus.qml` (glyph, label, click, scroll), `Drawers.toggle`, and `Osd`, which
already shows the microphone's mute changes.

## Proposed choices

1. **Defaults.** **All on:** `bar.showLogo`, `bar.showPower`, `bar.showMicrophone`,
   `bar.showLockKeys`, under Bar → Status icons; per screen with issue 35. Alternative:
   off until turned on. Reason: asked for, and the lock keys take no room while off.
2. **Order.** Start: logo, workspaces (then the window title, issue 38). End: lock keys,
   tray, Bluetooth, network, microphone, volume, battery, power.
3. **Microphone.** **Shown while there is an input; dimmed while muted; in the accent
   colour while an app records** (a PipeWire stream from a source). The shell's own
   visualiser and other captures of an output's monitor must not count; which node
   properties tell them apart is unchecked (look with `pw-dump` while the visualiser
   runs). Scrolling uses `bar.volumeStep`, up to 100 %. With issue 37, hovering opens the
   audio panel. Alternative: shown only while muted or recording. Reason: same place.
4. **Lock keys.** Hyprland sends no event for them (`activelayout` is for layouts only).
   **Binds in `custom-shell.nix`: `bindlni = , Caps_Lock, global, custom-shell:lockkeys`
   and the same for `Num_Lock`** (also while locked, not swallowed, any modifiers).
   Hyprland releases a `global` bind when the key comes up, so the shortcut's `released`
   fires, and the shell runs `hyprctl devices -j` once. A key is on when any keyboard
   says so: Hyprland's `main` keyboard here is a mouse's system-control device. It also
   reads at start and when game mode ends, and never in game mode. `cheatsheet/binds.js`
   leaves these binds out. Alternative: ask Hyprland's request socket with Quickshell's
   `Socket` (no process; unchecked that the reply arrives whole). Reason: one process
   per press, as the brightness keys run brightnessctl.
5. **Keyboard layout.** **Leave it to issue 63** (the layout switcher). This config sets
   no `kb_layout` (the desktop reports English (US)), so an entry now would always say
   US. Alternative: an entry here, hidden while only one layout exists.
6. **Clock.** **A click on the clock opens the dashboard;** today it does nothing.
   Alternative: leave it.

Cost: no timer. One `hyprctl` per Caps or Num Lock press, outside game mode. The
microphone reads PipeWire's nodes, as the volume icon does.

## Acceptance criteria

- [ ] The logo opens the launcher and the power button the session menu, on that screen.
- [ ] The microphone icon follows mute from anywhere (`wpctl`, the headset's button);
      a click toggles, scrolling changes the input volume.
- [ ] It shows the recording colour while an app records, and not for the visualiser.
- [ ] Caps Lock and Num Lock show within a moment of the key, and hide when off.
- [ ] Each switch hides its entry. Costs nothing in game mode.

## Blocked by

- None

## Comments

**2026-10-19:** All six choices approved as proposed, on the review page.
