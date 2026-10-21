# Tailscale's open-source CLI and tailscaled launchd daemon, not the App
# Store app, so there is no menu-bar icon. MagicDNS works through the
# /etc/resolver files tailscaled writes.
#
# The nix-darwin module also links /etc/resolver/ts.net into the store.
# tailscaled refuses to write through that symlink ("openat ts.net: path
# escapes from parent") and raises a DNS health warning, so drop the link and
# let tailscaled own the file.
#
# Once per Mac, after the first switch: `sudo tailscale up` (opens a browser
# to authenticate the node).
_: {
  flake.modules.darwin.tailscale = {
    services.tailscale.enable = true;
    environment.etc."resolver/ts.net".enable = false;
  };
}
