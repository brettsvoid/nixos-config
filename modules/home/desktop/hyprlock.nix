# Hyprlock's own config, off by request (a boot crash issue); the shells lock the
# session instead (docs/lock-screen.md). To use it, set enable = true: the
# system-level programs.hyprlock.enable, which also turns on hypridle, is already
# on in modules/system/nixos/hyprland.nix.
_: {
  flake.modules.homeManager.desktop-hyprlock = {
    programs.hyprlock.enable = false;
  };
}
