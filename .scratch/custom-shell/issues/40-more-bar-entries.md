# More bar entries

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

New entries in the bar:

- **OS logo** at the start: the NixOS snowflake (Nerd Font `nf-linux-nixos`, U+F313, in
  FiraCode Nerd Font). A click opens the launcher.
- **Power button** at the end. A click opens the session menu.
- **Microphone** beside the volume: mute state; a click toggles mute; scrolling changes
  the input volume.
- **Caps Lock and Num Lock**, each shown only while on.

Caelestia: `modules/bar/components/` (`OsIcon.qml`, `Power.qml`,
`status/LockStatus.qml`). Ideas only. Builds on `bar/StatusIcon.qml` and
`AudioStatus.qml` (glyph, label, click, scroll), `Drawers.toggle`, and `Osd`, which
already shows the microphone's mute changes.

## Proposed choices

1. **Defaults.** **All on:** `bar.showLogo`, `bar.showPower`, `bar.showMicrophone`,
   `bar.showLockKeys`, under Bar → Status icons; per screen with issue 35. Alternative:
   off until turned on. Reason: asked for, and the lock keys take no room while off.
2. **Order.** Start: logo, workspaces (then the window title, issue 38). End: lock keys,
   tray, Bluetooth, network, microphone, volume, battery, power.
3. **Microphone.** **Shown while there is an input; dimmed while muted; in the accent
   colour while an app records** (a PipeWire stream from a source). The shell's own
   visualiser and other captures of an output's monitor must not count; which node
   properties tell them apart is unchecked (look with `pw-dump` while the visualiser
   runs). Scrolling uses `bar.volumeStep`, up to 100 %. With issue 37, hovering opens the
   audio panel. Alternative: shown only while muted or recording. Reason: same place.
4. **Lock keys.** Hyprland sends no event for them (`activelayout` is for layouts only).
   **Binds in `custom-shell.nix`: `bindlni = , Caps_Lock, global, custom-shell:lockkeys`
   and the same for `Num_Lock`** (also while locked, not swallowed, any modifiers).
   Hyprland releases a `global` bind when the key comes up, so the shortcut's `released`
   fires, and the shell runs `hyprctl devices -j` once. A key is on when any keyboard
   says so: Hyprland's `main` keyboard here is a mouse's system-control device. It also
   reads at start and when game mode ends, and never in game mode. `cheatsheet/binds.js`
   leaves these binds out. Alternative: ask Hyprland's request socket with Quickshell's
   `Socket` (no process; unchecked that the reply arrives whole). Reason: one process
   per press, as the brightness keys run brightnessctl.
5. **Keyboard layout.** **Leave it to issue 63** (the layout switcher). This config sets
   no `kb_layout` (the desktop reports English (US)), so an entry now would always say
   US. Alternative: an entry here, hidden while only one layout exists.
6. **Clock.** **A click on the clock opens the dashboard;** today it does nothing.
   Alternative: leave it.

Cost: no timer. One `hyprctl` per Caps or Num Lock press, outside game mode. The
microphone reads PipeWire's nodes, as the volume icon does.

## Acceptance criteria

- [x] The logo opens the launcher and the power button the session menu, on that screen.
- [x] The microphone icon follows mute from anywhere (`wpctl`, the headset's button);
      a click toggles, scrolling changes the input volume. (Mute set from outside with
      `pw-cli` on a private server; `wpctl` and the headset button not tried.)
- [x] It shows the recording colour while an app records, and not for the visualiser.
      (A stand-in for the visualiser; the real one not run.)
- [x] Caps Lock and Num Lock show within a moment of the key, and hide when off.
      (Virtual keyboard in a nested Hyprland; the real keyboard not pressed.)
- [x] Each switch hides its entry. Costs nothing in game mode.

## Blocked by

- None

## Comments

**2026-10-19:** All six choices approved as proposed, on the review page.

**2026-10-23:** Built as approved, headless (`qs-test` with two outputs, a wlr virtual
pointer, a private PipeWire) and, for the lock keys, in a real Hyprland 0.56.2 nested in a
headless mutter on the iGPU. Checked:

- Clicks (virtual pointer, two outputs, the fake Hyprland has no focused monitor): the logo
  opened the launcher and the power button the session menu on the screen clicked, the
  clock the dashboard, and a second click on the same one closed it. The drawer's screen
  followed the bar clicked each time (a log line on `Drawers`).
- Microphone, private PipeWire with `QS_PIPEWIRE_IMMEDIATE_RECONNECT=1`: hidden with no
  server, shown once `default.audio.source` was set, hidden again when it named no node.
  `pw-cli set-param <id> Props '{ mute: true }'` was followed at once (log `muted=true`,
  crossed glyph, dimmed in a screenshot). A click toggled mute (Props `mute` true, then
  false); wheel steps of 5 % (Props `channelVolumes` 0.857375 = 0.95 cubed, then 0.614125 =
  0.85 cubed), stopping at 100 % on 22 notches up. A volume set to 130 % from outside was
  not raised by a notch up, and a notch down went to 125 %.
- Recording: an app stream linked from the default source gave `recording=true` and the
  accent colour (screenshot); a stream marked `stream.capture.sink` linked from the sink's
  monitor, as the visualiser's is (`custom-shell-spectrum`), gave nothing; muted while
  recording showed the crossed glyph, dimmed; stopping the app cleared it; an app on
  another source (not the default) counted. I did not test a paused capture.
- Lock keys: in a nested Hyprland with a persistent virtual keyboard and a real xkb
  keymap, a Caps Lock tap showed the entry 3 to 18 ms after the key came up
  (`hyprctl devices -j` read once), a second tap hid it; the same for Num Lock, with
  Num Lock on while Caps Lock was tapped, and with Shift held. `hyprctl binds -j` lists
  both binds as `locked` and `non_consuming`. The global shortcut was pressed and released
  with each tap. Game mode on: a tap gave no `hyprctl` call (counted), and when it ended
  one read showed the state. A shell started in game mode read nothing until it ended.
  With a stubbed `hyprctl` that lists two keyboards, one with Caps Lock on, the entry showed
  (any keyboard counts).
- Switches: with `bar.showPower` off everywhere, `showLogo` off on one screen and
  `showMicrophone` off on the other, each bar lost just those entries (screenshots).
  `showLockKeys` off hid both lock entries on a left-edge bar. A left-edge bar stacks
  logo, workspaces, clock, lock keys, tray, Bluetooth, network, microphone, volume, power.
- The cheatsheet leaves the lock binds out (`binds.js` run in Node on a sample).
- Rest cost, `qs-test` with a private PipeWire holding a default source and sink, 40 s:
  before this change 182.8 MB RSS, 0 CPU ticks, 1 frame; after 183.5 MB, 2 ticks, 1 frame.
  In game mode 174.5 MB and 0 ticks before, 175.4 MB and 0 ticks after, 0 frames both.
  No timer was added.
- `nix develop -c pre-commit run --all-files` passes, and brett-desktop's home builds
  (`qs-test --check` included). The built `hyprland.conf` has both `bindlni` lines.

Beyond the approved text, and why:

- A muted microphone that an app records from shows muted (dimmed), not accent: the choices
  say both. Muted wins because the app hears nothing.
- A recording is an active link from any source device to an app's capture stream, not
  only the default source, and the link's state has to be active.
- The lock keys' service starts when a screen first shows them; with `showLockKeys` off
  on every screen at start, it never starts. Turning the switch off later leaves it
  reading once per key press.
- The glyphs: caps `md-keyboard_caps` (U+F030E), num `md-dialpad` (U+F061C), microphone
  `md-microphone` and `md-microphone_off`, power `md-power`. Each is in FiraCode Nerd Font.
- `Drawers.toggle` takes an optional screen; `GameMode.loaded` is new (see the notes).
  `docs/quickshell-notes.md` has the PipeWire and virtual keyboard test facts.
- The start of the bar is now a `GridLayout` (`startItems`: logo, workspaces) like the end
  (`endItems`).

For issue 38 (window title): add it as a third child of `startItems` in `bar/Bar.qml`
(after `Workspaces`); the layout's width runs from `Theme.barPadding` towards the clock
(`clock.x` minus `Theme.spacingLarge`), so cap the title's width there and elide. The
pomodoro entry sits right of the clock, so it does not take that space.

Still to check on the desktop after the rebuild:

1. Press Caps Lock on your keyboard, then Num Lock: an icon for each appears at once at the
   end of the bar, left of the tray, and goes when you press the key again. Press Caps
   Lock in a window: capitals still type (the bind must not swallow the key).
2. `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, and the mute button on the headset: the
   microphone icon changes with each. Click it: mute toggles. Scroll over it: the input
   volume moves 5 % a notch (`wpctl get-volume @DEFAULT_AUDIO_SOURCE@`).
3. Open the dashboard on Overview with music playing (the visualiser runs): the microphone
   icon must keep its normal colour. Then record from an app (for example `pw-record
   /dev/null` in a terminal, stop with Ctrl+C): it takes the accent colour while it runs.
4. Click the logo, the power button and the clock on each screen: the launcher, session
   menu and dashboard open on the screen you clicked.
5. Question: is the accent colour on the microphone enough for "recording", or do you want
   the icon to change too?
6. Question: logo and power in plain bar colour, as built, or in the accent colour?

When 1 to 4 hold, set the status to done.
