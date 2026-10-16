# External monitor brightness

Status: ready-for-human
Type: HITL (needs the monitors)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Brightness for monitors over DDC/CI, set from the shell and the brightness keys, with
the OSD. Caelestia runs ddcutil per monitor (`services/Brightness.qml`; ideas only).

What exists (checked):

- The brightness keys run `brightnessctl s 5%+` and `5%-` (`hyprland.nix`) and fire
  `custom-shell:brightness`, after which the OSD (`services/Osd.qml`) reads
  `brightnessctl --class=backlight`. One shortcut serves both keys, so the shell does
  not know the direction. Only the laptop has a backlight.
- No `/dev/i2c-*` on the desktop: `hardware.i2c.enable` is off on both hosts. The
  NVIDIA driver does register six I2C adapters in sysfs, but its connectors
  (`card1-DP-1`, `card1-DP-2`) have no `ddc` link there, unlike the iGPU's.
- ddcutil 2.2.7 comes only from ambxst, which leaves with issue 23.
- Unchecked: whether the Odyssey G5 and the Dell AW2518H answer DDC/CI, whether the
  laptop's external monitor does, and whether any keyboard here sends the brightness
  keys (the Moonlander sends what its firmware maps).

## Proposed choices

1. **A hardware check first, before any shell code.** **A NixOS module `ddc`
   (`hardware.i2c.enable`, ddcutil in the system packages), imported by both hosts.**
   Its udev rule gives the seat's user access, so no group is needed. Rebuild, then
   run `ddcutil detect` and `ddcutil getvcp 10`. If no monitor answers, close this
   issue. Alternative: the desktop only.
2. **How the shell sets it.** **`ddcutil --bus N setvcp 10 <percent>`, one write per
   monitor at a time;** a newer value goes when it ends. The buses come from one
   `ddcutil detect --brief` at start and when a monitor is added, matched by EDID model
   and serial (whether ddcutil names NVIDIA's connectors is unchecked). Alternative:
   the ddcci kernel module (`ddcci-driver` in nixpkgs), which makes each monitor a
   backlight for brightnessctl; how it works with NVIDIA's adapters is unchecked.
   Reason: no out-of-tree module, and the shell controls how often it writes.
3. **Keys.** **`custom-shell:brightnessUp` and `custom-shell:brightnessDown` replace
   `custom-shell:brightness`, beside the brightnessctl binds.** On a DDC monitor the
   shell steps it by `brightness.step` (5 %, 1 to 20). On the laptop panel brightnessctl
   has already done it, and the shell only reads the level, as now. Alternative:
   `custom-shell-or` for the keys, which starts hyprctl and jq on each key repeat (35 a
   second while held). Question: which keys should it use if no keyboard sends them?
4. **Where.** **A Brightness card on the dashboard's Overview tab:** a slider per DDC
   monitor and the laptop panel, shown only when one exists. It makes the Overview
   taller (issue 48 gives each tab its own height). The OSD shows the focused screen's
   level, as for the backlight. Alternative: a bar popout (issue 37).
5. **Cost.** The levels are read when the card opens (one `getvcp` per monitor, as a
   monitor's own buttons send no event) and after a write. No polling or timers.
   Nothing runs in game mode unless a key is pressed.

## Acceptance criteria

- [ ] What `ddcutil detect` says for each monitor is recorded here (HITL).
- [ ] Each slider changes its monitor, and a fast drag ends at the last value. A
      monitor that does not answer DDC/CI gets no slider.
- [ ] The keys change the focused screen and show the OSD. The laptop panel works as
      before.
- [ ] No process runs while the card is closed and no key is pressed. It costs nothing
      in game mode.

## Blocked by

- None
