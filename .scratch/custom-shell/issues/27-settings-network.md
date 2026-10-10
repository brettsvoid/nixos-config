# Settings: network page

Status: ready-for-human
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A Network page in the settings window (issue 25), using Quickshell's Networking module
(NetworkManager). Wi-Fi networks here are NetworkManager's own profiles, not declared in
Nix, so the page may add and forget them.

- **Ethernet:** whether it is connected, and its details (address, link speed).
- **Wi-Fi:**
  - On/off.
  - The networks in range, with signal and security.
  - Connect (asking for the password when needed), disconnect, forget and autoconnect.
- Scan only while the page shows (performance rule 3).
- Show a failed connection, such as a wrong password, on the page.

brett-desktop is on Ethernet (`enp5s0`). Its Wi-Fi card (`wlp6s0`) is not in use, so
Wi-Fi can be tried there without losing the network. Leave Wi-Fi as you found it.
Connecting needs a password the agent does not have, so the user does that check.

## Acceptance criteria

- [x] The page shows the Ethernet connection and its address.
- [x] Wi-Fi on/off works and matches `nmcli radio wifi`.
- [x] Networks in range are listed while the page shows. Scanning stops when it closes.
- [ ] The user connects to a Wi-Fi network with its password from the page. A wrong
      password says so.
- [x] Forget and autoconnect change the NetworkManager profile (`nmcli connection`).

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md

## Comments

**2026-10-10:** Built in c2ab203 (`settings/NetworkPage.qml`). It was tested from the
working tree. Every criterion has passed except the one that needs a password, which is
yours: on the Network page, join a Wi-Fi network you know the password for, then try
one with a wrong password. It should say "Wrong password" and ask again. Close the
issue after that.

- **How it works:**
  - Ethernet's addresses come from `ip -j address`, because Quickshell has only the
    hardware address. It runs when the page opens and when the link changes.
  - Connect joins a saved or open network directly. A WPA or SAE network asks for the
    password first. NetworkManager reports a wrong password as "no secrets", so after a
    password has been given that reads "Wrong password".
  - Auto is the profile's `connection.autoconnect`, written through Quickshell's
    `NMSettings.write()`. A network that needs more than a password (802.1X) points to
    nm-connection-editor.
- **The scanner:** it is turned on when the page appears and off when it goes. A
  `Binding` did not put it back when destroyed, and scanning carried on after the window
  closed. Measured with NetworkManager's LastScan: 4 scans in 35 s with the page open,
  none after the window closed, and 1 in 35 s on a fresh shell before it opened.
- **Saved networks:** there are no saved Wi-Fi profiles here. To test, the Wi-Fi
  device's autoconnect was turned off and a temporary profile made for a network in
  range, with no password, so nothing could join. It showed as Saved with Auto off. Auto
  on and off changed the profile (yes, then no), and forget deleted it. The device's
  autoconnect was put back to yes afterwards, and Wi-Fi stayed disconnected throughout.
- **The password field:** Connect on an unknown secured network opened it, and Escape
  closed it without sending anything.
