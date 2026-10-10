# Bar status: tray, audio, network and Bluetooth

Status: done
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

Add the status area to the top bar, using Quickshell's built-in modules (SystemTray,
PipeWire, Networking, Bluetooth). All of it is event-driven; nothing polls.

- **Tray:** app tray icons; left click activates, right click opens the app's menu.
- **Audio:** an icon showing volume and mute; scrolling over it changes the volume,
  clicking toggles mute.
- **Network:** wired or Wi-Fi state, with signal strength for Wi-Fi.
- **Bluetooth:** on/off, and whether something is connected.

Richer pop-outs (picking a Wi-Fi network, pairing devices) are out of scope; they can
become drawers later.

## Acceptance criteria

- [ ] Tray icons appear for running tray apps, and their menus open on right click.
- [ ] The audio icon tracks volume and mute changes from any source; scroll and click
      work.
- [ ] Unplugging the network cable or dropping Wi-Fi shows on the bar within a few
      seconds.
- [ ] Turning Bluetooth on or off, or connecting a device, shows on the bar.
- [ ] Hidden or absent hardware (no Wi-Fi card, no Bluetooth) hides that icon.
- [ ] No timers or process spawns are added for any of this.

## Blocked by

- .scratch/custom-shell/issues/02-shell-skeleton.md

## Comments

**2026-10-10:** Done, tested live on brett-desktop (wired, an idle Wi-Fi card, a Bluetooth
adapter with nothing paired).
- Right of the bar: tray, Bluetooth, network, audio, battery (`bar/Tray.qml`,
  `BluetoothStatus.qml`, `NetworkStatus.qml`, `AudioStatus.qml`, sharing
  `StatusIcon.qml`). Glyph codepoints come from Nerd Fonts' `glyphnames.json`. All of it
  binds to Quickshell's SystemTray, PipeWire, Networking and Bluetooth objects; the bar
  files have no Timer or Process.
- Tray: Steam's icon shows; right click opened Steam's menu. Platform menus need
  Quickshell's QApplication mode, so `shell.qml` now starts with
  `//@ pragma UseQApplication`. The menu is plain Qt-styled; drawing it ourselves from
  `QsMenuOpener` would match the frame, later.
- Audio: a `wpctl` change to 55% showed at once; the wheel moved it 5% a notch both
  ways; clicks muted (dimmed muted glyph) and unmuted; volume restored to 0.40. The
  glyph and label keep the width of their widest values (mute glyph, "100%"), so the
  icons beside them do not shift.
- Bluetooth: `bluetoothctl power off` showed the off glyph, `power on` the normal one.
  The connected glyph and count were not seen: nothing is paired.
- Network: shows wired. Not tested unattended: pulling the cable (it would cut this
  session's connection) and Wi-Fi strength (the card is not connected).
- Quickshell's Networking module logs "Unable to determine system time zone" when
  `TZDIR` is unset. That only happened in the test terminal; the session exports
  `TZDIR=/etc/zoneinfo` from `/etc/set-environment`, and with it the warning is gone.
