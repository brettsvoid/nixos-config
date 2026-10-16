# Bar popouts for the status icons

Status: ready-for-human
Type: HITL (the hover timing and the looks, and joining a real Wi-Fi network)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Resting the pointer on a status icon opens a small panel out of the bar next to it,
joined to the frame as the drawers are:

- **Network:** the wired link; Wi-Fi on or off, networks with their signal, joining
  (with a password prompt) and disconnecting.
- **Bluetooth:** on or off; paired devices to connect or disconnect, with their battery
  where BlueZ gives it.
- **Audio:** the outputs (click one to make it the default) with volume and mute; the
  default input with its volume and mute.
- **Battery** (laptop): level, charging, time to full or empty; the power profile once
  issue 56 adds it.
- Each ends with a link to its settings page.

Caelestia: `modules/bar/popouts/` (they open at once on hover). ambxst:
`modules/bar/ControlsButton.qml`. Ideas only. The Network, Bluetooth and Audio settings
pages (issues 26 to 28) already join, pair and pick defaults. `frame/Drawer.qml` draws
panels joined to the frame, but only centred on an edge or at one of its ends.

## Proposed choices

1. **Opening.** **A panel opens once the pointer rests 150 ms on an icon, moves to
   another icon at once, and closes 300 ms after the pointer leaves icon and panel.**
   Clicks keep their jobs: the volume icon still mutes and scrolls; a click on the
   others opens their settings page. Alternative: open on click, with mute in the panel.
   Reason: as Caelestia, and a click on the volume icon mutes today.
2. **Shared parts.** **Move the lists out of the settings pages into components
   (`components/WifiList.qml`, `BluetoothDevices.qml`, `AudioDevices.qml`) used by
   both.** Alternative: separate, smaller panels. Reason: one join and password flow.
3. **Placement.** **`Drawer` gains a position along its edge (the icon's centre), kept
   inside the frame;** on a side bar the panel comes out sideways. One panel at a time.
   None opens while a drawer is open on that screen, and a drawer opening closes it.
   Notification pop-ups wait while a panel shows, as for drawers (both default to the
   top right). The panel needs a frame shape: the shader takes 8 and all 8 are in use,
   so issue 67's change (pass only the drawers that show) comes first.
4. **Keyboard.** **Not taken on hover** (like the OSD). A click in the password field
   takes it; Escape closes the panel.
5. **Costs.** Content loads only while shown, as drawers do. The Wi-Fi scanner runs only
   while the network panel shows. **Bluetooth discovery never starts on hover,** only
   from a "Look for devices" button. PipeWire nodes are tracked only while the audio
   panel shows. In game mode and fullscreen the bar is hidden, so nothing opens.
6. **Setting.** `bar.popouts` (default on), on the Bar page; per screen with issue 35.
   Alternative: a delay setting too. Reason: one switch until the delay proves wrong.
7. **Not included:** tray menus stay Qt menus. The clock gets no panel; the dashboard's
   Overview has the calendar.

## Acceptance criteria

- [ ] Each panel opens on hover next to its icon, joins the bar with fillets on all four
      bar edges, and closes after the pointer leaves.
- [ ] Joining a Wi-Fi network with a password works from the panel (the desktop's
      `wlp6s0`).
- [ ] The volume icon still mutes on click and changes the volume on scroll.
- [ ] Bluetooth discovery runs only after the button, and stops when the panel closes.
- [ ] No panel opens while a drawer is open on that screen; pop-ups never overlap one.
- [ ] Nothing loads or scans while no panel shows. Costs nothing in game mode.

## Blocked by

- None
