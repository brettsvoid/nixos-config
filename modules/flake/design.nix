# Design constants used by more than one module:
#
#   flake.lib.theme     — fonts, terminal look, the Catppuccin palette
#   flake.lib.wallpaper — default desktop picture
#
# Consumers close over the flake-parts `config`
# (`theme = config.flake.lib.theme;`), as edgebar.nix does for bar-geometry.nix.
_: {
  flake.lib.theme = {
    font = {
      # FiraCode Nerd Font: "Mono" for the terminals, the proportional variant
      # for UI text (the game launcher). sketchybarrc and the quickshell
      # Theme.qml hardcode the family, so a font swap must edit those too.
      mono = "FiraCode Nerd Font Mono";
      ui = "FiraCode Nerd Font";
      size = 13;
    };

    # Shared by ghostty and kitty so the two compare like for like.
    # Scrollback stays per terminal.
    terminal = {
      opacity = 0.95;
      padding = 8;
    };

    # Catppuccin Mocha. starship takes the whole palette, hyprland a few
    # roles. Hex includes the leading '#'.
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
