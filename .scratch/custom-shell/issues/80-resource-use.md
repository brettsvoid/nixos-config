# Keep the shell's resource use down, and release more in game mode

Status: ready-for-agent
Type: AFK (measure on the desktop when no game runs); the questions at the end need you

## Parent

.scratch/custom-shell/PRD.md

## What to build

The goal (stated 22 Oct 2026): the shell uses as little VRAM, RAM and CPU as it can,
and game mode releases as much as it can. This issue keeps the measurements and the
open leads; check it again when the shell changes.

### How to measure

- VRAM per process: `nvidia-smi` (the process table). `qs-test` renders in software,
  so it shows no VRAM; measure on the desktop.
- To find what a part costs, run a throwaway `quickshell -p <dir>` with a minimal
  config (transparent `PanelWindow`s on the Background layer, `mask: Region {}`) and
  read its pid's VRAM after about 5 s. Use the shell's environment
  (`QSG_RHI_BACKEND`, `DISABLE_MANGOHUD=1`). Not while a game runs.
- CPU: the shell's utime + stime from `/proc/<pid>/stat` over 30 s or more.
- RAM: `VmRSS` and `RssAnon` in `/proc/<pid>/status`.

### Measured

22 Oct 2026, brett-desktop (RTX 3080 Ti 12 GB, NVIDIA 595), screens 2560x1440 and
1080x1920:

| What | Vulkan | OpenGL |
|---|---|---|
| The shell, all drawers closed | 560 MiB | 200–242 MiB |
| Probe: 1 one-pixel window | 6 MiB | |
| Probe: 2 empty screen-sized windows per screen | 215 MiB | 99 MiB |
| The same, drawing a rectangle or the wallpaper | 345 MiB | 100 MiB |

- Done: the shell renders on OpenGL (2ab01d8). Shaders need `--glsl "300 es,330"`
  for it (custom-shell.nix, compileShaders).
- Now, on OpenGL: VRAM 200 MiB, RSS 411 MiB (212 MiB anonymous), 9 threads, idle CPU
  0.1% of a core.
- The rest of the desktop at the same time: Hyprland 237 MiB, Steam's web helpers
  ~260 MiB, kitty 92–136 MiB, Firefox 50–146 MiB. nvidia-smi's total was about 400 MiB
  more than the processes add up to, and the driver reserves another 379 MiB.

### Leads to check

1. The shell's ~100 MiB of VRAM above the bare windows (200 MiB against the 100 MiB
   probe): fonts, icons, the bar, loaded drawers, notification images, the 8 edge
   windows. Remove parts in a probe copy to see which costs what.
2. The shell's RAM: 411 MiB RSS. Find what holds it (QML engine, JS heap, decoded
   images, icon theme).
3. Game mode keeps the wallpaper and frame windows mapped. ScreenShell.qml does this on
   purpose for fullscreen: remapping takes about 120 ms a window, and a faded Top
   surface still lets a game be solitary. Game mode toggles rarely, so measure what it
   would free to:
   - let go of the wallpaper image while game mode is on (`source: ""`), and
   - unmap the wallpaper and frame windows while it is on.

   For each: the VRAM freed, whether the game is still `solitary` in
   `hyprctl monitors`, and how long the shell takes to come back when game mode goes
   off.
4. What in the shell still wakes up in game mode: compare its CPU ticks over 60 s with
   game mode on and off, and list timers, animations and processes that run while
   nothing of the shell shows.
5. Hyprland in game mode: `game-mode on` turns off blur, shadows and animations. Check
   whether Hyprland's VRAM (237 MiB) drops, or its buffers stay allocated.
6. The ~400 MiB that nvidia-smi counts but gives to no process: find out what it is
   before deciding anything.
7. If the media player widget comes back (media-player.nix, no host imports it now), it
   still sets `QSG_RHI_BACKEND=vulkan`.

## Acceptance criteria

- [ ] Leads 1–6 measured, with the numbers in Comments, and the changes they justify
      made or split into their own issues
- [ ] The lock screen still blurs on OpenGL: Super+L, and the screen behind the clock
      is blurred, not sharp or black
- [ ] Settings' window effect previews still animate on OpenGL: Super+I, then the
      "Window effects" page; each preview plays its effect
- [ ] The questions below answered

## Questions for you

1. Should game mode reach beyond the shell and Hyprland? Steam's web helpers alone hold
   ~260 MiB of VRAM. Options: (a) leave other apps alone; (b) measure what Steam with
   its GPU rendering off (`-cef-disable-gpu`) costs and frees, then decide; (c) let
   game mode close or restart named apps (which ones?).
2. Is a short delay acceptable when game mode goes off (about 120 ms a window if the
   shell unmaps its windows), if it frees a useful amount of VRAM?

## Blocked by

None

## Comments
