# Settings: Bluetooth page

Status: ready-for-human
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

- [x] Adapter on/off works and matches `bluetoothctl show`. The bar's icon follows.
- [ ] Paired devices are listed and connect or disconnect from the page.
- [x] Discovery runs only while the page shows.
- [ ] The user pairs a device from the page, and forgets it again.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md

## Comments

**2026-10-10:** Built in f5b7f61 (`settings/BluetoothPage.qml`). It was tested from the
working tree. What is left needs a device of yours, so it is your check: pair it from
Nearby, then connect, disconnect and forget it under Paired devices. Close the issue
after that.

- **How it works:**
  - The page shows only named devices nearby; unnamed ones are mostly beacons.
  - A device paired here is then trusted and connected.
  - The shell runs no BlueZ agent. A device that asks for a PIN or a passkey
    confirmation will not pair here; use `bluetoothctl` with `agent on` for those. Most
    headsets, mice and controllers need neither. If yours fails to pair, that is the
    likely reason, and running an agent in the shell would be a new issue.
  - The adapter's Pairable flag is off here. BlueZ says it affects only pairing that
    other devices start, not pairing from this machine.
- **Results:**
  - The page listed the adapter (brett-desktop, hci0), no paired devices and 7 named
    devices nearby.
  - Discovering was yes with the page open, and no on another page or once the window
    closed.
  - The switch turned the adapter off and on, and the bar's icon followed.
  - Discovery has to wait until the adapter's `state` is Enabled. Started as soon as
    `enabled` turned true, BlueZ refused it ("Resource Not Ready").
  - The adapter was left powered, as found.
