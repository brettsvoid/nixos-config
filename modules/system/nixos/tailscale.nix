# Tailscale's tailscaled and CLI, as on the Macs (darwin/tailscale.nix).
# openFirewall opens tailscaled's UDP port (41641), so peers can connect
# directly rather than through a DERP relay. tailscale0 is not a trusted
# interface: tailnet peers reach only the ports the firewall already opens
# to the LAN, such as SSH.
#
# Once per host, after the first switch: `sudo tailscale up` (prints a URL
# to authenticate the node).
_: {
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
