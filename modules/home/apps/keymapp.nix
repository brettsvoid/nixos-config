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

      # Keymapp gives its window a maximum size of 2560x1440. Before Hyprland's
      # dwindle layout tiles a window, it compares that maximum with the tile
      # the window would split, and floats the window if the tile is larger.
      # On the desktop's portrait monitor every tile is 1898 px tall, so
      # Keymapp always floated there, wider than the screen. no_max_size makes
      # Hyprland ignore the maximum. GTK still draws the window at most
      # 1440 px tall, so alone on that monitor it leaves a gap under it.
      wayland.windowManager.hyprland.settings.windowrule = [
        "no_max_size on, match:class ^(keymapp)$"
      ];
    };
}
