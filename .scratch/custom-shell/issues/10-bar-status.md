# Bar status: tray, audio, network and Bluetooth

Status: ready-for-agent
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
