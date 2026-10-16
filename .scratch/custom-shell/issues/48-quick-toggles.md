# Quick toggles on the dashboard

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A row of round buttons on the dashboard's Overview tab. Each shows whether a thing is on;
a click turns it on or off. Caelestia: `modules/utilities/cards/Toggles.qml`; ambxst:
`QuickControls.qml` (ideas only).

Five can be built now, each on something the shell already has (checked):

- **Wi-Fi:** `Networking.wifiEnabled`, as the Network page does. brett-desktop has a
  Wi-Fi device too (`wlp6s0`, not connected), so it shows on both hosts.
- **Bluetooth:** `Bluetooth.defaultAdapter.enabled`, as the Bluetooth page does.
- **Microphone:** the mute of `Pipewire.defaultAudioSource`, which `services/Osd.qml`
  already tracks; a change also shows the microphone OSD.
- **Do not disturb:** `Notifications.doNotDisturb` and `setDoNotDisturb()`.
- **Game mode:** `GameMode.on`; a click runs `game-mode on|off`, as the launcher does.
  Turning it on closes the dashboard (`services/GameMode.qml`); Super+Shift+G turns it
  off.

Three join the row when their issues land: **Keep awake** (55), **VPN** (61) and
**Night light** (58).

## Proposed choices

1. **Where: a row along the bottom of the Overview tab.** Alternatives: a "Controls"
   tab, or only the bar pop-outs (issue 37). Reason: Super+D opens on the Overview.
   Today every tab is 320 px high (`Dashboard.qml`). Give each tab its own height, so
   only the Overview grows; the drawer eases between sizes (`frame/Drawer.qml`). With
   this row and the header row of issues 49 and 52, the Overview is about 480 px, which
   fits the laptop's 1080 px. Whichever of the three lands first adds per-tab heights.
2. **Look: 48 px round buttons, a short label under each.** On is `Theme.primary`, off
   `surfaceContainer`. Alternative: icons only, with tooltips. Reason: eight icons are
   hard to tell apart, and 760 px has room for labels.
3. **Microphone is lit while it is live,** as in Caelestia. Alternative: a "Mute" button
   lit while muted. Reason: every button then reads "lit means on".
4. **A toggle hides when its thing is missing** (no Wi-Fi device, adapter or input), and
   dims while blocked (`wifiHardwareEnabled` false, adapter state `Blocked`).
5. **Right-click opens its settings page** (Network, Bluetooth, Audio, Notifications),
   closing the dashboard first, as the cog does.
6. **Settings,** on the Dashboard page's Overview section: `dashboard.showToggles`
   (`true`) and `dashboard.hiddenToggles` (`[]`; `"wifi"`, `"bluetooth"`,
   `"microphone"`, `"dnd"`, `"gameMode"`, and the three later ones).
7. **The launcher gets the missing ones:** "Turn Wi-Fi off/on", "Turn Bluetooth off/on"
   and "Mute/Unmute microphone" in `launcher/ActionsMode.qml`. Alternative: no change.
8. **Cost:** the row exists only while the Overview shows. No process and no timer,
   except `game-mode` once per click.

## Acceptance criteria

- [ ] Each toggle shows the true state, and a click changes it; the Network, Bluetooth
      and Audio pages agree. Wi-Fi off on brett-desktop leaves the wired link up.
- [ ] Before a Bluetooth test, `bluetoothctl devices Connected` lists nothing; if it
      lists a device, leave that check for the user.
- [ ] A missing device hides its toggle, with no QML warnings (check in `qs-test`).
- [ ] Right-click opens the right page. `dashboard.hiddenToggles` works from Nix too.
- [ ] Only the Overview grows; the other tabs keep 320 px.
- [ ] Costs nothing in game mode or with the dashboard closed.

## Blocked by

- None for the first five toggles.
- .scratch/custom-shell/issues/55-idle-inhibitor.md (its toggle only)
- .scratch/custom-shell/issues/58-night-light.md (its toggle only)
- .scratch/custom-shell/issues/61-vpn-toggles.md (its toggle only)
