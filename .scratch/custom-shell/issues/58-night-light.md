# Night light

Status: ready-for-human
Type: HITL (the tint needs judging on both screens and the laptop's panel)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A warmer screen at night, switched by hand or on a schedule. ambxst toggles wlsunset
(`modules/services/NightLightService.qml`); ideas only.

Checked:

- hyprsunset 0.4.0 and wlsunset 0.4.0 are in nixpkgs. hyprsunset sets a colour matrix
  (CTM) through Hyprland's own protocol and answers `hyprctl hyprsunset temperature N`,
  `identity` and `gamma`. Its schedule has fixed times only. wlsunset sets the gamma
  table, at fixed times or at sunset from a latitude and longitude. At run time it
  only takes SIGUSR1, which steps through forced cool, forced warm and automatic.
- Hyprland hands the CTM to the display hardware (`Renderer.cpp`, aquamarine). Both
  NVIDIA outputs take it: `drm_info` shows CTM and a 1024-entry gamma table, and
  Hyprland's log says "crtc supports CTM" for DP-1 and DP-2. So the tint costs no
  frames. When hyprsunset exits, Hyprland puts the identity matrix back.
- HDR is off (`render:cm_enabled = false`; both screens 8-bit sRGB), so the CTM goes
  straight to the screen. `render:non_shader_cm` is at its default (ignore), so a
  fullscreen game keeps the tint. Hyprland fades each change (`render:ctm_animation`
  auto is on for NVIDIA 575 and later).
- From the code, not on screen: screenshots and the colour picker (issue 59) read the
  frame before the CTM, so they keep true colours. gpu-screen-recorder (issue 57) adds
  the gamma table only for HDR or KDE's night light (`src/capture/kms.c`), so a
  recording should be untinted.

## Proposed choices

1. **hyprsunset.** Alternative: wlsunset, for sunset times from a location. Reason: the
   shell can change and query it at run time.
2. **The shell runs `hyprsunset -t <K>` as a Process while night light is on.** Stopping
   it ends the tint. A new temperature goes through `hyprctl hyprsunset temperature`
   once the slider is let go. Alternative: home-manager's `services.hyprsunset` with
   profiles in Nix, the shell only switching `identity`. Reason: the settings window
   owns it all, as for idle. A shell restart drops the tint for a moment.
3. **Fixed times.** Alternative: sunset and sunrise from a location, worked out in the
   shell (the weather issue, 49, also needs a location). Reason: no location needed.
   A one-minute timer runs while the schedule is on, and pauses in game mode; the
   schedule catches up when game mode ends. A single long timer could fire late after
   the laptop sleeps (unchecked).
4. **Settings, in a "Night light" section on the Appearance page:**
   - `nightLight.enabled` (false): on now. A launcher action ("Turn night light on" or
     "off"), the quick toggle (issue 48) and IPC (issue 34) flip it.
   - `nightLight.schedule` (false), `nightLight.startMinute` (1200, 20:00) and
     `nightLight.endMinute` (420, 07:00), in steps of 15, shown as times. At each the
     shell sets `enabled`; a flip by hand holds until the next.
   - `nightLight.temperature` (4000 K; 1000 to 6500, step 100).
   - `nightLight.offInGameMode` (false). It costs no frames, so it stays by default.
5. **No bar icon and no keybind.** Alternatives: an icon while on; Super+Shift+N (free
   today). Reason: the screen itself shows it.

## Acceptance criteria

- [ ] On, both monitors warm to the set temperature; off, they return to normal.
- [ ] A new temperature applies without a flash of normal colours.
- [ ] The schedule switches at its times; a flip by hand holds until the next.
- [ ] A fullscreen game keeps the tint, or drops it with `offInGameMode`, and its frame
      time does not change (MangoHud).
- [ ] The setting survives `toggle-shell restart`; quitting the shell resets colours.
- [ ] A screenshot and a picked colour taken with it on have true colours.
- [ ] The laptop's panel takes the tint (you; its CTM support is unchecked).
- [ ] Nothing runs while it and the schedule are off. In game mode the timer pauses.

## Blocked by

- None
