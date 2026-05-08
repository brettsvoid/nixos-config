_: {
  flake.modules.homeManager.terminals-kitty =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      terminal = {
        font = {
          family = "FiraCode Nerd Font Mono";
          size = 13;
        };
        opacity = 0.95;
        padding = 8;
        margin = 8;
        scrollback = 4000;
      };
    in
    {
      programs.kitty = {
        enable = true;
        font = {
          name = terminal.font.family;
          inherit (terminal.font) size;
        };
        themeFile = "Catppuccin-Mocha";
        settings = {
          # Cursor
          cursor_shape = "beam";
          cursor_beam_thickness = "1.5";
          cursor_trail = 3;
          cursor_trail_decay = "0.1 0.2";

          # Scrollback
          scrollback_lines = terminal.scrollback;

          # Window
          enabled_layouts = "Tall,*";
          window_border_width = 0;
          window_margin_width = terminal.margin;
          window_padding_width = terminal.padding;
          single_window_margin_width = 0;
          single_window_padding_width = "${toString terminal.padding} ${toString terminal.padding}";
          active_border_color = "none";
          inactive_text_alpha = "0.4";
          dim_opacity = "0.4";
          background_opacity = builtins.toString terminal.opacity;

          # Background. Image is shipped from the repo; nix-store path is
          # stable across rebuilds so kitty doesn't lose its wallpaper if
          # ~/.config gets cleaned.
          background_image = "${./kitty/anime-neko-ninja-wallpaper-rework.png}";
          background_image_layout = "cscaled";
          background_image_linear = "yes";
          background_tint = "0.95";
          background_tint_gaps = "1";

          # Bell
          enable_audio_bell = "no";
          visual_bell_duration = 0;

          # Tab bar
          tab_bar_style = "powerline";
          tab_powerline_style = "round";
          tab_bar_edge = "bottom";
          tab_bar_min_tabs = 2;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          # Wayland / Linux-only
          linux_display_server = "wayland";
          wayland_titlebar_color = "background";
          hide_window_decorations = "yes";
        }
        // lib.optionalAttrs pkgs.stdenv.isDarwin {
          # macOS-only
          background_blur = 20;
          hide_window_decorations = "titlebar-only";
          macos_titlebar_color = "background";
          macos_option_as_alt = "yes";
          macos_thicken_font = "0.2";
        };
        keybindings = {
          # Splits
          "ctrl+shift+d" = "launch --cwd=current --location=vsplit";
          "ctrl+shift+e" = "launch --cwd=current --location=hsplit";
          "ctrl+shift+enter" = "new_window_with_cwd";

          # Navigate (vim-style)
          "ctrl+shift+h" = "neighboring_window left";
          "ctrl+shift+l" = "neighboring_window right";
          "ctrl+shift+k" = "neighboring_window up";
          "ctrl+shift+j" = "neighboring_window down";

          # Tabs
          "ctrl+shift+t" = "new_tab_with_cwd";
          "ctrl+shift+1" = "goto_tab 1";
          "ctrl+shift+2" = "goto_tab 2";
          "ctrl+shift+3" = "goto_tab 3";
          "ctrl+shift+4" = "goto_tab 4";
          "ctrl+shift+5" = "goto_tab 5";

          # Layout toggle
          "ctrl+shift+z" = "toggle_layout stack";

          # Word jump
          "alt+left" = "send_text all \\x1b[1;3D";
          "alt+right" = "send_text all \\x1b[1;3C";

          # Vim-style cursor motion in shells
          "alt+h" = "send_text all \\x1b[D";
          "alt+l" = "send_text all \\x1b[C";
        };
      };
    };
}
