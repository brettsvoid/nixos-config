# Tailscale via nix-darwin's `services.tailscale`: installs the open-source
# `tailscale` CLI and runs the `tailscaled` daemon under launchd
# (com.tailscale.tailscaled, RunAtLoad). This is the headless/CLI client —
# NOT the Mac App Store GUI app, so there's no menu-bar icon; the connection
# is managed entirely from the terminal. MagicDNS works via the
# /etc/resolver/ts.net file the upstream module drops in.
#
# One-time bootstrap after `darwin-rebuild switch`:
#   sudo tailscale up        # opens a browser to authenticate this node
# Thereafter `tailscale status`, `tailscale up/down`, etc. just work.
_: {
  flake.modules.darwin.tailscale = {
    services.tailscale.enable = true;
  };
}
