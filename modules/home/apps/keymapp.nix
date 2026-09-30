# Keymapp — ZSA's app for flashing firmware and showing the live layout
# (the active layer and each key's binding) of a ZSA keyboard. The desktop's
# keyboard is a Moonlander Mark I. The Macs install it as a Homebrew cask.
#
# Import both halves: the NixOS half gives the logged-in user access to the
# keyboard, the home-manager half installs the app.
_: {
  # nixpkgs' zsa-udev-rules: the keyboard's hidraw nodes (vendor 3297) and
  # the Moonlander's STM32 DFU bootloader (0483:df11) get TAG+="uaccess", so
  # the logged-in user can reach them without root.
  flake.modules.nixos.apps-keymapp = {
    hardware.keyboard.zsa.enable = true;
  };

  flake.modules.homeManager.apps-keymapp =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.keymapp ];
    };
}
