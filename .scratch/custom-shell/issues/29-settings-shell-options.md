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
