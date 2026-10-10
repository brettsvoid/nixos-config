# Settings: Bluetooth page

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A Bluetooth page in the settings window (issue 25), using Quickshell's Bluetooth module.
brett-desktop has an adapter (`hci0`).

- Adapter on/off.
- Paired devices, with connect and disconnect, battery level where the device reports
  it, and forget.
- Discover nearby devices only while the page shows (performance rule 3). Pair one, and
  cancel a pairing.

Pairing needs a real device in pairing mode, so the user does that check. The bar's
Bluetooth icon reads the same adapter and should follow.

## Acceptance criteria

- [ ] Adapter on/off works and matches `bluetoothctl show`. The bar's icon follows.
- [ ] Paired devices are listed and connect or disconnect from the page.
- [ ] Discovery runs only while the page shows.
- [ ] The user pairs a device from the page, and forgets it again.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md
