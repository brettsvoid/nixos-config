# Settings: network page

Status: ready-for-agent
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

- [ ] The page shows the Ethernet connection and its address.
- [ ] Wi-Fi on/off works and matches `nmcli radio wifi`.
- [ ] Networks in range are listed while the page shows. Scanning stops when it closes.
- [ ] The user connects to a Wi-Fi network with its password from the page. A wrong
      password says so.
- [ ] Forget and autoconnect change the NetworkManager profile (`nmcli connection`).

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md
