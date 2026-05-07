# Hyprlock — currently disabled by request (boot crash issue noted in main).
# When ready to enable, flip enable = true; the system-level
# `programs.hyprlock.enable` is already on in modules/system/nixos/hyprland.nix.
_: {
  flake.modules.homeManager.desktop-hyprlock = {
    programs.hyprlock.enable = false;
  };
}
