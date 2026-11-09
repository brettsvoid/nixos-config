# Keymapp: ZSA's app for flashing firmware and showing the live layout of a
# ZSA keyboard (the desktop has a Moonlander Mark I). The mac mini installs
# it as a Homebrew cask.
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
      # patchelf 0.19.2 breaks keymapp 1.3.7: autoPatchelf sets the interpreter
      # and then the rpath, and the second step adds a program header that the
      # first step's new LOAD segment does not cover, so ld.so segfaults in
      # dl_main before main. Setting a long rpath first avoids it: the real one
      # then fits in place. Drop this when a plain pkgs.keymapp starts.
      home.packages = [
        (pkgs.keymapp.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            patchelf --set-rpath "$(printf '%4096s' "")" "$out/bin/keymapp"
          '';
        }))
      ];

      # Keymapp sets a maximum window size of 2560x1440, and dwindle floats a
      # window whose tile would exceed its maximum, so on the desktop's
      # portrait monitor (tiles 1898 px tall) it always floated, wider than
      # the screen. no_max_size makes Hyprland ignore the maximum; GTK still
      # caps it at 1440 px tall, leaving a gap beneath it there.
      wayland.windowManager.hyprland.settings.window_rule = [
        {
          match.class = "^(keymapp)$";
          no_max_size = true;
        }
      ];
    };
}
