# NetworkManager: interactive nmcli / nmtui control.
# Avahi answers <hostname>.local over mDNS, e.g. `ssh brett-desktop.local`.
# Publishing is off by default, and without publish.addresses the host
# hears queries but never answers for its own name. openFirewall (default
# on) opens UDP 5353.
_: {
  flake.modules.nixos.networking = {
    networking.networkmanager.enable = true;

    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
      };
    };
  };
}
