# Screen recording

Status: ready-for-human
Type: HITL (a game recording, sound and the laptop need checking by hand)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Record the focused monitor or a picked region, with or without sound, with pause, a
bar indicator and a list of recordings. Caelestia (`services/Recorder.qml`, which polls
`pidof`) and ambxst (`modules/services/ScreenRecorder.qml`) drive gpu-screen-recorder;
ideas only. It follows the screenshot module (issue 20): a script for any shell, binds
with descriptions, notify-send actions with a ten-minute timeout.

Checked: gpu-screen-recorder 6.1.2 and `gsr-cli` are in nixpkgs. The NixOS option
`programs.gpu-screen-recorder.enable` installs them with a `gsr-kms-server` wrapper
(`cap_sys_admin`) for monitor capture; today ambxst's module turns it on, so it goes
with issue 23. Targets are a monitor name, `region` (`WxH+X+Y`, slurp's format, also
through KMS) or `portal`. `gsr-cli` has `set-paused true|false`, and `stop`, which
replies once the file is saved. Each start writes an NVIDIA profile so that CUDA does
not lower memory clocks in games (driver 580+; the desktop has 595). That profile is
not in `~/.nv`, so it has never run here. No video player is installed, and
`xdg-open` opens folders in kitty, not Thunar.

## Proposed choices

1. **gpu-screen-recorder with KMS capture**, enabled in
   `modules/system/nixos/hyprland.nix` for both hosts. Alternative: `-w portal`, which
   needs no helper but asks which screen every time. Reason: NVENC and no picker.
2. **A `screen-record start monitor|region | pause | stop` script** in a new
   `modules/home/desktop/screen-recording.nix`. It keeps `$XDG_RUNTIME_DIR/screen-record`
   (state, file, start time, paused seconds) and removes it at the end. The shell
   watches that file, as `GameMode.qml` does. The script reads the settings with jq,
   as `generate-theme` does. Alternative: the shell runs the recorder. Reason: any
   shell, and a shell restart keeps the recording.
3. **MP4, H.264 (its default), 60 fps.** Settings on a new Tools page (issue 59 adds
   to it): `recording.folder` (`~/Videos/Recordings`), `recording.fps` (60; 24 to
   240), `recording.audio` (`desktop`; or `none`, `desktop-mic`). Alternative: MKV,
   which survives a crash.
4. **Keys (free today): Super+Shift+R records the monitor or stops; Super+Ctrl+R records
   a region (a click takes a window, as for screenshots); Super+Alt+R pauses.**
   Launcher actions do the same. Alternative: launcher actions only.
5. **The bar shows a red dot and the time while recording, dimmed when paused.** A click
   stops; a right click pauses. A 1 s timer runs only then; the time comes from the
   state file. "Saved" offers Open and Show (in Thunar).
6. **Game mode: recording carries on; the bar and its timer hide; the notifications
   wait in the history.** Alternative: a critical pop-up at the start. Reason: nothing
   is drawn over the game.
7. **The list: a launcher mode, prefix `rr` (`launcher.recordingsPrefix`)**, newest
   first, with date and size, from a FolderListModel (no process). Enter opens one.
   Deleting stays in Thunar, as the launcher has no second action. Alternative: a
   dashboard tab.
8. **Showtime 50.0 as the video player**, beside Loupe in `hyprland.nix`'s `mimeApps`.
   Alternative: mpv 0.41.0. Reason: it matches Loupe.
9. **No replay buffer ("save the last 30 s").** Reason: it keeps the encoder running.

## Acceptance criteria

- [ ] Each key works on both monitors; DP-2's video is upright (it is rotated).
- [ ] Stop saves to `~/Videos/Recordings` and notifies; Open plays it in Showtime.
- [ ] Paused time is left out of the video and the bar's time. `rr` lists the files.
- [ ] Each sound setting records what it names (you, with real sound).
- [ ] Recording a game in game mode costs only the encoder's share (MangoHud frame
      times with and without; you).
- [ ] The laptop records its panel (you).
- [ ] With issue 23 merged, the recorder and its wrapper are still installed.
- [ ] Nothing runs while not recording.

## Blocked by

- None
