# VPN toggles

Status: ready-for-human
Type: HITL (a VPN login, or a WireGuard file to import)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Turn a VPN on and off from the shell, and see whether one is up. Caelestia does this
for WireGuard, Tailscale, WARP and NetBird through each one's command line
(`services/VPN.qml`; ideas only).

Checked: neither Linux host has Tailscale, wireguard-tools or a NetworkManager VPN
plugin (`networking.networkmanager.plugins` is empty), and the desktop has no VPN
profile. The two Macs run Tailscale (`modules/system/darwin/tailscale.nix`); the M1
MacBook Pro also gets wireguard-tools from Homebrew.

NetworkManager 1.58.1 has WireGuard as its own connection type, with no plugin, and
nmcli imports a wg-quick file (`nmcli connection import type wireguard file wg0.conf`).
OpenVPN and OpenConnect need plugins (both are in nixpkgs). The Network page uses
Quickshell's Networking module, which lists only Wi-Fi and wired devices, so VPN
profiles need nmcli.

## Proposed choices

1. **Which VPN.** **Tailscale, on both Linux hosts.** The Macs already use it, so all
   four machines share one network. Alternatives: WireGuard profiles in
   NetworkManager, for a server you name (no daemon, no package); both; or none, which
   closes this issue. Question: what is the MacBook's wireguard-tools for, and should
   these hosts reach that server too?
2. **Setup.** For Tailscale: a NixOS module `tailscale`, imported by both hosts, with
   `services.tailscale.enable` and `extraSetFlags = [ "--operator=brett" ]`, so
   `tailscale up` and `down` need no sudo. Then `sudo tailscale up` once per host to
   log in. For WireGuard: no Nix change. Import the file with nmcli once per host; the
   key then stays in NetworkManager's root-only profile, not in the repo.
3. **How the shell reads and switches it.** **On demand.** It reads the state when the
   Network page or the quick toggles (issue 48) show, and a second after each switch.
   Tailscale: `tailscale status --json --peers=false`, `tailscale up`, `tailscale down`.
   NetworkManager: `nmcli -t -f NAME,UUID,TYPE,ACTIVE connection show`, keeping types
   `wireguard` and `vpn`, and `nmcli connection up|down uuid <uuid>`. Alternative: one
   long-running watcher (`nmcli monitor`, or `tailscale debug watch-ipn`, a debug
   command whose output may change) for a live bar icon. Reason: VPN state changes
   rarely, and nothing runs between reads.
4. **Where it shows.** **A VPN section on the Network settings page:** a switch per
   VPN, its state and its address. Failures show under the switch, as Wi-Fi ones do.
   Issue 48's row gets the VPN toggle it plans for: it switches the last VPN used,
   kept in the shell's state, and whichever of the two lands second adds it. No bar
   icon, unless 3's alternative is chosen; then `bar.showVpn` (true) shows a shield
   beside the network icon while a VPN is up.
5. **Cost.** No timers. Processes run only when the page or the toggles open, and on a
   switch. Nothing runs in game mode.

## Acceptance criteria

- [ ] The chosen VPN is set up on both hosts and logged in (HITL).
- [ ] The Network page's switch turns it on and off with no password prompt. A
      failed switch says why.
- [ ] The quick toggles' VPN toggle switches the last VPN used.
- [ ] No process runs while neither the page nor the toggles show. It costs nothing
      in game mode.

## Blocked by

- None. The toggle needs .scratch/custom-shell/issues/48-quick-toggles.md's row.
