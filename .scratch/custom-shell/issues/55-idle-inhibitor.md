# Keep awake (idle inhibitor)

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A "keep awake" switch. While it is on, the session is never idle, so the shell's idle
lock and screens-off (issue 29, `lock/Idle.qml`) wait. Caelestia
(`modules/utilities/cards/IdleInhibit.qml`) and ambxst
(`modules/services/CaffeineService.qml`) have one; ideas only.

Checked in the sources:

- Quickshell's `IdleInhibitor` (`Quickshell.Wayland`) takes a window and `enabled`, and
  makes an idle-inhibit-unstable-v1 inhibitor on that window's surface.
- Hyprland 0.56 counts an inhibitor while its surface is mapped
  (`src/managers/input/IdleInhibitor.cpp`). The frame windows stay mapped under a
  fullscreen window and in game mode (`frame/ScreenShell.qml`).
- The shell's two `IdleMonitor`s set `respectInhibitors: true`, so Hyprland holds them
  back for any app's inhibitor, this one included.
- hypridle has no idle rules here (it only locks before sleep, `custom-shell.nix`), so
  nothing changes there. Keep awake does not stop sleep from the menu or the lid.
- With both idle settings at Never (the default), keep awake has no effect. It matters
  once a lock or screens-off time is set.

## Proposed choices

1. **A new `services/KeepAwake.qml` singleton with `on`, and an `IdleInhibitor` in each
   screen's `FrameWindow` bound to it.** Alternative: one on the first screen only.
   Reason: one mapped inhibitor is enough, and unplugging a screen cannot drop it.
2. **It lasts until turned off, through shell restarts, but not into a new login:** the
   state is a file in `$XDG_RUNTIME_DIR`, as game mode's is. Alternatives: lost at each
   shell restart (a rebuild restarts the shell), or kept in `~/.local/state` for good.
   Reason: a rebuild should not end it, and a forgotten switch should not outlive the
   login.
3. **On or off only.** Alternative: also "for 1 hour". Reason: no timer, and neither
   upstream has one.
4. **No Hyprland rule for fullscreen windows.** Alternative: `idle_inhibit fullscreen` on
   every window. Reason: game mode already pauses the idle monitors, and an app that
   must stay awake can inhibit for itself.
5. **Where it shows:** a bar icon (a Nerd Font cup) only while on, which turns it off on
   a click (`bar.showKeepAwake`, default true, Bar page); launcher actions "Keep awake"
   and "Stop keeping awake" (`>`); and a switch on the Session page under "When idle",
   which shows the runtime state and is not a schema key. The quick toggle (issue 48)
   and an IPC target (issue 34) come with those issues. No keybind (Super+Shift+I is
   free if you want one).
6. **Cost:** no process and no timer; one Wayland object per screen while on. Game mode
   changes nothing, as its idle monitors are already off.

## Acceptance criteria

- [ ] With "Lock after" at 1 minute and keep awake on, a minute idle does not lock.
      With it off, it locks. The same holds for "Screens off".
- [ ] It still holds with a fullscreen window on each screen.
- [ ] It survives `toggle-shell restart`, and is off after logging in again.
- [ ] The bar icon shows only while it is on, and a click turns it off.
- [ ] The launcher action, the Session switch and the bar icon agree.
- [ ] qs-test (its headless sway has idle-inhibit): switching it on logs no inhibitor
      warning, and the load check passes.
- [ ] Costs nothing in game mode or while off: no process, no timer.

## Blocked by

- None
