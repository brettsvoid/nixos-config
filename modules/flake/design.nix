# Shared design constants (flake.lib), so values used by more than one module
# live in one place instead of being hand-synced.
#
#   flake.lib.theme     — font + the Catppuccin palette
#   flake.lib.wallpaper — default desktop picture
#
# Consumers close over the flake-parts `config` (e.g. `{ config, ... }: let
# theme = config.flake.lib.theme; in …`), the same way bar-geometry.nix is read
# by edgebar.nix. See modules/home/darwin/bar-geometry.nix for the pattern.
_: {
  flake.lib.theme = {
    font = {
      # FiraCode Nerd Font: the "Mono" variant for terminals/editors, the
      # proportional variant for bars. Same family, so a font swap is one edit.
      mono = "FiraCode Nerd Font Mono";
      ui = "FiraCode Nerd Font";
      size = 13;
    };

    # Appearance shared by the ghostty/kitty A/B so the experiment compares
    # the terminals, not divergent settings. (scrollback stays per-terminal.)
    terminal = {
      opacity = 0.95;
      padding = 8;
    };

    # Catppuccin Mocha, single-sourced. starship consumes the whole palette;
    # hyprland consumes a few roles. Hex includes the leading '#'.
    catppuccin.mocha = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
      text = "#cdd6f4";
      subtext1 = "#bac2de";
      subtext0 = "#a6adc8";
      overlay2 = "#9399b2";
      overlay1 = "#7f849c";
      overlay0 = "#6c7086";
      surface2 = "#585b70";
      surface1 = "#45475a";
      surface0 = "#313244";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";
    };
  };

  flake.lib.wallpaper = {
    # Relative to $HOME. edgebar/wallpaper/ambxst all point here.
    dir = "Pictures/Wallpapers";
    default = "chisato_petals_of_silence_4k.jpg";
  };
}
