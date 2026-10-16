# Battery warnings and hibernating at a critical level

Status: ready-for-human
Type: HITL (needs the laptop)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Warn when the laptop's battery runs low, and make sure it hibernates before it runs
out. Caelestia toasts at 20, 10 and 5 %, and hibernates at 3 % after a 5 s warning
(`modules/BatteryMonitor.qml`; ideas only). Laptop only: the desktop has no battery.

What exists (checked):

- The bar's battery icon (`bar/BatteryStatus.qml`) reads UPower. Quickshell gives
  `percentage` and `UPower.onBattery`, but not UPower's own warning level.
- UPower already acts, on both hosts (NixOS defaults, read with `nix eval`): low at
  20 %, critical at 5 %, and `CriticalPowerAction=HybridSleep` at 2 %. It falls back
  to Hibernate, then PowerOff, when that is not available.
- The laptop is set up to hibernate: a swap partition with `boot.resumeDevice` on it,
  NVIDIA's power management on, and `hyprland-resume-monitors` after hibernation.
- Unchecked: whether the swap is at least as large as the RAM, and whether
  hibernation has ever worked on the laptop. The laptop runs ambxst until issue 23.

## Proposed choices

1. **Who hibernates.** **UPower, as now.** The shell only warns, and its critical
   warning says the laptop hibernates at 2 %. (Hybrid sleep writes the hibernation
   image, then sleeps.) Alternative: the shell hibernates at its own
   level (`systemctl hibernate` after a 5 s warning), with UPower as the backstop; or
   `services.upower.criticalPowerAction = "Hibernate"`, so a nearly empty battery does
   not also keep the RAM powered. Reason: UPower acts even when the shell is not
   running, and one owner means two actions cannot race.
2. **The warnings.** **Two notifications through `notify-send`: at 20 % (normal) and at
   5 % (critical).** These are UPower's own levels. A critical notification shows even
   in game mode and do-not-disturb (`services/Notifications.qml`). Each shows once per
   discharge. Plugging in the charger dismisses them. If the shell starts below a
   level on battery, it warns once. Alternative: Caelestia's three levels; or toasts
   (issue 67). Reason: the lock screen already uses notify-send, and the history
   keeps the warning.
3. **Settings.** `battery.warnings` (true), `battery.lowPercent` (20, 5 to 50) and
   `battery.criticalPercent` (5, 3 to 20), in a Battery group on the Session page,
   shown only where there is a laptop battery.
4. **Cost.** Event-driven: UPower's percentage changes arrive over D-Bus. No timers.
   One notify-send per warning. Nothing runs on the desktop.

## Acceptance criteria

- [ ] On battery, crossing each level gives one notification. The critical one shows
      in game mode.
- [ ] Plugging in dismisses them. Unplugging and falling again warns again.
- [ ] On the desktop nothing runs.
- [ ] Steps on the laptop (HITL):
  1. Run `swapon --show` and `free -h`, and note both here. The swap should be at
     least the RAM's size.
  2. Save your work and run `systemctl hibernate`. Does the laptop power off, then
     come back at the lock screen with both screens on?
  3. On battery, set Low to one above the current level. A warning should come at the
     next drop. Plug in: it should go.

## Blocked by

- .scratch/custom-shell/issues/23-laptop-session-shell.md
