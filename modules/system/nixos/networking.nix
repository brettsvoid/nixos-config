# NetworkManager: interactive nmcli / nmtui control.
_: {
  flake.modules.nixos.networking = {
    networking.networkmanager.enable = true;
  };
}
