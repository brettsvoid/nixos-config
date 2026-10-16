# Power profiles

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Show and switch the power profile (Power saver, Balanced, Performance) through
power-profiles-daemon (ppd). Caelestia has it in its battery popout
(`modules/bar/popouts/Battery.qml`); ambxst runs `powerprofilesctl`
(`modules/services/PowerProfile.qml`); ideas only.

Checked:

- ppd 0.30 runs on the desktop. On main it comes from ambxst's NixOS module; the
  issue 23 branch sets it itself for both hosts (`modules/system/nixos/hyprland.nix`).
- The desktop offers performance, balanced (in use) and power-saver, through
  `intel_pstate`. The laptop's list is unchecked.
- Quickshell's `PowerProfiles` (`Quickshell.Services.UPower`) follows ppd over D-Bus:
  `profile` (settable), `hasPerformanceProfile`, `degradationReason` and `holds`. It
  has no "available" flag, so the shell cannot tell that ppd is missing.
- ppd's polkit policy lets the active session switch without a password
  (`switch-profile`). Not yet tried from the shell.
- ppd keeps the choice itself (`/var/lib/power-profiles-daemon/state.ini`, named in
  its binary; absent, as the profile has never changed).

## Proposed choices

1. **Quickshell's `PowerProfiles`.** Alternative: `powerprofilesctl`, as ambxst does.
   Reason: no process and no polling.
2. **Three buttons at the top of the dashboard's Performance tab.** Performance is
   disabled without `hasPerformanceProfile`. A line under them names a degradation
   (heat, lap) or an app holding a profile. Setting `dashboard.showPowerProfile`
   (default true). Alternative: the Overview tab. Reason: it sits with the CPU figures.
3. **Launcher actions (`>`): "Power profile: power saver", "balanced" and
   "performance",** marked "In use" as the colour schemes are. No keybind.
4. **A bar icon only while the profile is not Balanced;** a click opens the dashboard
   on the Performance tab. Setting `bar.showPowerProfile` (default true). Alternative:
   no bar icon. The battery popout (issue 37) and quick toggle (issue 48) reuse this.
5. **Game mode leaves the profile alone.** GameMode (Feral 1.8.2, profile-gaming)
   already sets the CPU governor to performance while a `gamemoderun` game runs.
   Alternative: game mode holds Performance through ppd's `HoldProfile`, which needs a
   process (`powerprofilesctl launch`), as Quickshell cannot hold one. Unchecked: how
   GameMode's governor and ppd's setting combine on this CPU.
6. **The shell stores nothing; ppd keeps the choice.** Alternative: a shell setting
   applied at start. Reason: one owner for the value.
7. **Cost:** no process and no timer, only D-Bus property changes. The icon hides with
   the bar in game mode.

## Acceptance criteria

- [ ] The desktop shows three profiles with Balanced marked. Picking one changes
      `powerprofilesctl get` at once, with no password prompt.
- [ ] `powerprofilesctl set power-saver` in a terminal shows in the shell at once.
- [ ] The bar icon shows for Power saver and Performance only.
- [ ] The launcher actions switch the profile and mark the one in use.
- [ ] The build's load check, which has no ppd, passes.
- [ ] (You) the laptop shows the profiles it has, and switching works.
- [ ] Costs nothing in game mode: no process or timer.

## Blocked by

- None
