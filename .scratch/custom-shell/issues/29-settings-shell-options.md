# Settings: options for the shell's parts

Status: ready-for-human
Type: HITL (which options are worth having)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Settings for the shell's own parts: the bar, dashboard, launcher, notifications, OSD and
lock screen. They go on one page of the settings window (issue 25), or a few.

Caelestia's Panels page and ambxst's Ambxst page are the reference. Between them they
offer dozens of toggles, for example seconds on the clock, how many workspaces show, how
many launcher results show, and the notification timeout.

First list what each part could sensibly offer, then go through the list with the user.
Build only the options they want. Each option is a value in the settings file that the
part reads instead of a fixed value.

Not wanted: a Hyprland page or a keybind editor like ambxst's. Those settings are
declared in Nix, and editing them live would fight the config.

## Acceptance criteria

- [x] The user has chosen the options. The list and the choices are recorded here.
- [ ] Each chosen option changes the shell at once and survives a restart.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md

## Comments

**2026-10-15:** The list, drawn from what is fixed in the shell today and from Caelestia's
and ambxst's settings pages. The value after each option is today's. The user chose
all of them.

- **Bar:**
  1. 12- or 24-hour clock, for the bar and the lock screen (24-hour).
  2. Seconds on the clock (off).
  3. The date beside the time (on).
  4. How many workspaces (10).
  5. Show empty workspaces (shown, dimmed).
  6. Scroll over the workspaces to switch (no scrolling).
  7. Only this monitor's workspaces (the same 1–10 on every screen).
  8. Which status icons show: tray, Bluetooth, network, audio, battery (all).
  9. The volume percentage beside its icon (always).
  10. The volume's scroll step and maximum (5 %, 100 %).
  11. The bar only on chosen screens (every screen).
  12. The bar on another edge (top only).
  13. Auto-hide the bar (always shown).
- **Dashboard:**
  14. Which tabs show (all four).
  15. Open on the last tab used (always Overview).
  16. The day the week starts on (Monday).
  17. The visualiser on the media card (on).
  18. The visualiser's bars (32).
  19. Which performance cards show (CPU, GPU, memory, swap, disks, network).
  20. Units: binary or decimal bytes, °C or °F (binary, °C).
  21. The graphs' length and sample interval (60 samples, 1 s).
- **Launcher:**
  22. Rows shown (8).
  23. Rank apps by how often they are opened, with a reset (always on, never reset).
  24. The terminal for terminal apps (kitty).
  25. The modes' prefixes (`cc`, `=`, `>`).
  26. Ask before log out, restart and shut down, here and in the session menu (no
      confirmation).
- **Notifications:**
  27. The pop-up timeout when the app sets none (5 s).
  28. Use the app's own timeout (always).
  29. The most pop-ups at once (no limit).
  30. Where pop-ups show (top right).
  31. A limit on the history, by count or age (none).
  32. Lines of body text in a pop-up (4).
- **OSD:**
  33. How long it stays (1.5 s).
  34. Which kinds show: volume, microphone, brightness (all).
  35. Where it shows (bottom centre).
  36. Hide it in game mode (it shows).
- **Lock screen and session:**
  37. The wallpaper's blur and dimming on the lock screen (blur on, 50 % dim).
  38. Media controls on the lock screen (shown while something plays).
  39. Lock after N minutes idle, and turn the screens off after M (never).
  40. Sleep in the session menu (only in the launcher's actions).
- **Wallpaper:**
  41. The wallpaper folder (`~/Pictures/Wallpapers`, written into four files).
  42. Crop or fit (crop).
  43. Change the wallpaper every N minutes (never).

**2026-10-15:** All 43 are built, on worktree branch `worktree-shell-options`. Each
setting's default is today's behaviour, so nothing changes until you choose otherwise.
Every key can also be set from Nix (`local.customShell.settings`, issue 30); the keys
are in `quickshell/config/Settings.qml`'s `schema`.

- **Where they are in the settings window:**
  - **Appearance:** the wallpaper's folder, fill and timed change.
  - **Bar** (new): 1 to 13.
  - **Dashboard** (new): 14 to 21.
  - **Launcher** (new): 22 to 25.
  - **Notifications** (new): 27 to 36.
  - **Session** (new): the lock screen, idle, and the session menu (26, 37 to 40).
- **Commits:** `2f709d3` qs-test, `f8dd78b` bar, `93817f8` dashboard, `1b5e7e3`
  launcher and session menu, `b5b3bbe` notifications and OSD, `bbca1d5` lock and idle,
  `d576e27` wallpaper. Each commit message lists what was checked in qs-test.
- **Choices made while building:**
  - The launcher, cheatsheet and dashboard hang from the bar, so they move with it.
    The session menu and notification history stay on the right.
  - Auto-hide keeps the bar up while a drawer is open on that screen, so the drawer
    does not move under the pointer.
  - The volume maximum is for scrolling over the bar's icon. The volume keys
    (`wpctl` in `hyprland.nix`) have no maximum, as before.
  - Confirm covers log out, restart and shut down, not lock or sleep.
  - Idle locking and screens off pause in game mode, as a game played with a
    controller sends no Wayland input.
  - The timed wallpaper change pauses in game mode too, as the new theme costs a
    matugen run and recoloured apps.
- **Fixed on the way:** pop-ups' timeouts started again whenever another pop-up came
  or went (each card was made again). They now keep their own time.

To check on the desktop, which qs-test cannot show (it draws no shaders, has no tray
apps, PipeWire or real screens):

1. Bar → Edge: try Bottom, Left and Right. The frame should join the bar with curved
   corners on each edge, and the launcher (Super+R) should come out of the bar. Right
   click a tray icon on a bottom or side bar; its menu should open beside the icon,
   on screen.
2. Bar → Auto-hide on: the windows should move up to the frame. Point at the top edge:
   the bar should slide over the windows, and go shortly after you leave it.
3. Bar → Screens: turn one screen off. That screen's top edge should become as thin
   as the others.
4. Bar → Workspaces → Per screen on: each bar should show only its own screen's
   workspaces.
5. Session → Lock screen: lock (Super+L) with Blur at 30 % and at 100 %, and say which
   you prefer.
6. Session → When idle: set Screens off to 1 minute and leave the desktop alone for a
   minute. The screens should go off, then come on when you move the mouse. Set it
   back to Never afterwards if you don't want it.
7. Restart the shell (`toggle-shell restart`). Your settings should still be there.
