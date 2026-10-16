# A clock and a visualiser on the wallpaper

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A large clock and date on the wallpaper, and spectrum bars along the bottom of the
wallpaper while music plays. Caelestia has both (`modules/background/`: clock in nine
places with a scale, bars that show only while every window floats); ideas only.

- Builds on: `frame/WallpaperWindow.qml` (one screen-sized window per screen, on the
  Background layer), `dashboard/Visualiser.qml` and the `Spectrum` type from issue 13,
  `SystemClock` as `bar/Clock.qml` uses it, and Mpris for "something plays".
- Measured in issue 13: the dashboard open with its bars moving cost about 3–4% of one
  core more than closed (spectrum 0.4%, the rest redrawing about 47 times a second). Each
  `Spectrum` starts its own PipeWire capture (`shell-native/src/capture.rs`).
- Hyprland 0.56 (read in its source): any commit to a Background- or Bottom-layer surface
  marks its cached blur stale, and it blurs the background again if a tiled window that
  is not fully opaque shows. Here `inactive_opacity` is 0.95, so any inactive one counts.

## Proposed choices

1. **The clock sits inside the wallpaper window.** It changes once a minute, so the
   window redraws once a minute. Alternative: its own small window. Reason: no extra
   surface for one redraw a minute.
2. **Clock look: the time large, the date under it, on a rounded card** in the theme's
   surface colour at 60% opacity. Alternatives: text only (hard to read on a busy
   wallpaper); a soft shadow (needs MultiEffect, which the PRD rules out). It follows
   `clock.twelveHour`, and shows no seconds.
3. **The bars get their own window per screen**: a strip along the bottom inside the
   frame, a fifth of the screen high, on the Bottom layer, no input. It exists (a
   `LazyLoader`) only while it shows. Reason: Qt Quick renders the whole window for any
   change, and the wallpaper window is screen-sized.
4. **The bars show only while the desktop is in view**: something plays, the workspace
   on that screen has no windows, nothing is fullscreen, game mode is off and the screen
   is not locked. Alternative: also while every window floats (Caelestia); that needs
   `Hyprland.refreshToplevels()` after each float change, as `HyprlandToplevel` has no
   floating property. Reason: with no windows Hyprland skips its blur update (as above;
   not so with issue 77's xray blur on), and nothing hides the bars.
   Both this and issue 78 need "desktop in view": add it once to `ScreenShell.qml`.
5. **Settings** (the **Desktop** page, shared with issues 71 to 73):
   `desktop.clock` (off), `desktop.clockPosition` (`"bottom-right"`; `top-left`, `top`,
   `top-right`, `left`, `centre`, `right`, `bottom-left`, `bottom`, `bottom-right`),
   `desktop.clockScale` (1, 0.5–2, step 0.1), `desktop.visualiser` (off),
   `desktop.visualiserBars` (64, 16–128, step 8), `desktop.hiddenScreens` (`[]`,
   screens with neither, named as in `bar.hiddenScreens`). Alternative: both on by
   default. Reason: off keeps today's look.
6. **Reuse `Visualiser.qml`** with its bar count as a property rather than read from
   `dashboard.visualiserBars`.
7. **Cost:** no package and no process. The clock's `SystemClock` stops in game mode and
   while the screen is locked. Each screen showing bars runs its own capture.

## Acceptance criteria

- [ ] The clock shows at each position and scale, on every screen not hidden.
- [ ] The bars move with the music on an empty workspace, and go when a window opens,
      the music pauses, a window goes fullscreen, or the screen locks.
- [ ] No capture runs and the strip window does not exist while the bars do not show.
- [ ] CPU with the bars moving on one screen is measured and noted here.
- [ ] It costs nothing in game mode: no capture, no clock ticks.
- [ ] Each setting applies at once and survives a restart.
- [ ] On the desktop: the clock reads well on three different wallpapers.

## Blocked by

- None
