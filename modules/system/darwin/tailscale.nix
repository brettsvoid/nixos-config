# Tailscale's open-source CLI and tailscaled launchd daemon, not the App
# Store app, so there is no menu-bar icon. MagicDNS works through the
# /etc/resolver/ts.net file the module writes.
#
# Once per Mac, after the first switch: `sudo tailscale up` (opens a browser
# to authenticate the node).
_: {
  flake.modules.darwin.tailscale = {
    services.tailscale.enable = true;
  };
}
