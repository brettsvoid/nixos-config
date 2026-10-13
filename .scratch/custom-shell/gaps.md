# Gaps against Caelestia and ambxst

A brainstorming list from the comparison on 2026-10-12, against Caelestia at 454f46d and
ambxst at 59edec9. The plan is to add them all. Take them one at a time: talk one
through, write it up as an issue under `issues/`, then note the issue's number here.

Each entry names where Caelestia or ambxst has it. Read their code for ideas only (see
the PRD's licence decision). Paths are relative to their sources in the Nix store, from
the flake inputs `caelestia-shell` and `ambxst`.

Not on the list: ambxst's keybind editor and Hyprland page. Those settings are declared
in Nix (issue 29).

## Bar

- [ ] **Hover popouts for the status icons.** These are a Wi-Fi list with a password
      prompt, Bluetooth devices, audio devices with volume, and the battery with its
      power profile. Caelestia: `modules/bar/popouts/`. ambxst has controls and clock
      popups: `modules/bar/ControlsButton.qml`, `modules/bar/clock/`.
- [ ] **Active window title.** Caelestia shows a live preview on hover. The preview
      opens a window info panel that can move, float, pin or kill the window:
      `modules/bar/popouts/ActiveWindow.qml`, `modules/windowinfo/`. ambxst shows the
      title in its notch when nothing plays.
- [ ] **Workspaces.** Show app icons per workspace and special workspaces, and switch
      workspace by scrolling. Caelestia: `modules/bar/components/workspaces/`. ambxst:
      `modules/bar/workspaces/`.
- [ ] **More bar entries.** An OS logo that opens the launcher, a power button, a
      microphone icon, the keyboard layout, and caps and num lock. Caelestia:
      `modules/bar/components/`.
- [ ] **Bar options.** These are the position, auto-hide, and hiding the bar on chosen
      screens. ambxst: `config/defaults/bar.js`. They overlap with issue 29.

## Launcher

- [x] Calculator: issue 32.
- [x] Actions (lock, power, theme, wallpaper, game mode and others): issue 33.
- [ ] **Emoji picker,** with recent emoji and skin tones. ambxst (`ee`):
      `modules/widgets/dashboard/emoji/EmojiTab.qml`.
- [ ] **Notes,** in rich text or Markdown. ambxst (`nn`):
      `modules/widgets/dashboard/notes/NotesTab.qml`.
- [ ] **Tmux sessions:** create, attach, rename and kill. ambxst (`tt`):
      `modules/widgets/dashboard/tmux/TmuxTab.qml`.
- [ ] **Search by field.** `@` prefixes search apps by category, description, command or
      keywords. Caelestia: `modules/launcher/services/Apps.qml`.
- [ ] **Favourite and hidden apps.** Caelestia: `plugin/src/Caelestia/Models/appdb.cpp`
      and the Apps page in its settings app.
- [ ] **Richer clipboard history.** Add images with previews, pinning, aliases and full
      text search. ambxst keeps it in SQLite: `modules/services/ClipboardService.qml`.
- [ ] **Per-app actions.** Pin an app to a dock, or make a desktop shortcut. ambxst:
      `modules/widgets/launcher/`.

## Dashboard and panels

- [ ] **Quick toggles.** These are Wi-Fi, Bluetooth, microphone mute, do not disturb,
      game mode, the idle inhibitor, VPN and night light. Caelestia:
      `modules/utilities/cards/Toggles.qml`. ambxst:
      `modules/widgets/dashboard/widgets/QuickControls.qml`.
- [ ] **Weather.** Show current conditions and a forecast, from Open-Meteo, with the
      location from the IP address or a chosen city. Caelestia: `services/Weather.qml`
      and `modules/dashboard/WeatherTab.qml`. ambxst:
      `modules/services/WeatherService.qml`.
- [ ] **Fuller media player.** Add shuffle, loop and a choice of player. Today's card
      has cover art, the track, previous, play-pause and next, and seeking. Caelestia:
      `modules/dashboard/media/`. ambxst:
      `modules/widgets/dashboard/widgets/FullPlayer.qml`.
- [ ] **Lyrics** for the playing track, from local files, LRCLIB or NetEase. Caelestia:
      `plugin/src/Caelestia/Services/lyrics.cpp`.
- [ ] **User card** with an avatar (`~/.face`) and uptime. Caelestia:
      `modules/dashboard/dash/`.
- [ ] **Pomodoro timer.** ambxst: `modules/bar/clock/`.
- [ ] **Beat-synced animation.** Caelestia has a bongocat GIF that keeps time with the
      music (aubio): `plugin/src/Caelestia/Services/beattracker.cpp`.

## System

- [ ] **Idle inhibitor** (keep awake). Caelestia:
      `modules/utilities/cards/IdleInhibit.qml`. ambxst:
      `modules/services/CaffeineService.qml`.
- [ ] **Power profiles** through power-profiles-daemon. Caelestia has it in its battery
      popout. ambxst: `modules/services/PowerProfile.qml`.
- [ ] **Screen recording,** of the whole screen or a region, with or without sound,
      with pause and a list of recordings. Both use gpu-screen-recorder. Caelestia:
      `services/Recorder.qml`. ambxst: `modules/tools/`.
- [ ] **Night light.** ambxst uses wlsunset: `modules/services/NightLightService.qml`.
- [ ] **Colour picker.** ambxst: `modules/widgets/tools/ToolsMenu.qml`.
- [ ] **OCR, QR and barcode scanning, Google Lens.** ambxst: `scripts/`.
- [ ] **VPN toggles** for WireGuard, Tailscale and others. Caelestia:
      `services/VPN.qml`.
- [ ] **External monitor brightness** through ddcutil. Caelestia:
      `services/Brightness.qml`.
- [ ] **Keyboard layout switcher.** Caelestia: `modules/bar/popouts/`.
- [ ] **Battery warnings,** and hibernating at a critical level. Caelestia:
      `modules/BatteryMonitor.qml`.
- [ ] **EasyEffects** bypass and presets. ambxst:
      `modules/services/EasyEffectsService.qml`.
- [ ] **Update checker.** ambxst: `modules/services/UpdateService.qml`. On NixOS this
      could mean a flake input that is behind upstream.

## Notifications

- [x] History kept across restarts: issue 31.
- [ ] **Toasts.** Short messages for charging, caps lock, a switched audio output, game
      mode and now playing. Caelestia: `modules/utilities/toasts/`.
- [ ] **Pop-up handling.** Swipe or drag to dismiss, expand and collapse, and copy the
      body. Caelestia: `modules/notifications/Notification.qml`. ambxst:
      `modules/notifications/`.

## Lock screen

- [ ] **Fingerprint and face unlock** through fprintd and howdy. Caelestia:
      `modules/lock/Pam.qml`, `assets/pam.d/`. Needs the hardware.
- [ ] **More on the lock screen.** Caelestia adds an avatar, weather, the
      notifications, and system information. Caelestia: `modules/lock/`.

## Desktop and windows

- [ ] **Workspace overview** with live window previews. Windows can be dragged between
      workspaces. ambxst: `modules/widgets/overview/`.
- [ ] **Dock** with pinned apps and running indicators. ambxst: `modules/dock/`.
- [ ] **Desktop icons** from `~/Desktop`. ambxst: `modules/desktop/`.
- [ ] **Desktop clock and a visualiser on the wallpaper.** Caelestia:
      `modules/background/`.

## Theme

- [ ] Fixed palettes and recolouring the wallpaper: issue 16.
- [ ] **Theme presets:** save, rename and switch whole looks. ambxst:
      `modules/services/PresetsService.qml`, `assets/presets/`.
- [ ] **Theming other apps** with the palette: GTK, Qt, kitty, Neovim and Discord.
      ambxst: `modules/theme/*Generator.qml`. Here home-manager writes GTK and Qt, so
      decide which apps follow the wallpaper.
- [ ] **Transparency setting.** Caelestia: `services/Colours.qml`.
- [ ] **More wallpaper kinds:** GIF and video wallpapers, subfolders and search. ambxst:
      `modules/widgets/dashboard/wallpapers/`.

## Control

- [ ] **IPC.** Other programs and scripts could then drive the shell, with commands
      such as `qs ipc call drawers toggle launcher`. Caelestia has about a dozen
      targets: drawers, lock, notifications, media, wallpaper, brightness and others
      (`modules/Shortcuts.qml` and services). ambxst: `ambxst run <command>`
      (`modules/services/GlobalShortcuts.qml`).
- [ ] Settings for each part of the shell: issue 29.
- [ ] **Per-monitor settings.** Caelestia: `monitors/<name>/shell.json`.
- [ ] **Searching the settings window.** ambxst:
      `modules/widgets/dashboard/controls/SettingsTab.qml`.

## Other

- [ ] **AI assistant chat** with a shell tool that asks before it runs. ambxst:
      `modules/services/Ai.qml`, `modules/widgets/dashboard/assistant/`.
