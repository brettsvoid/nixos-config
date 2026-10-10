{ config, ... }:
let
  theme = config.flake.lib.theme;
in
{
  flake.modules.homeManager.terminals-kitty =
    {
      lib,
      pkgs,
      ...
    }:
    let
      terminal = {
        font = {
          family = theme.font.mono;
          inherit (theme.font) size;
        };
        inherit (theme.terminal) opacity padding;
        margin = 8;
        scrollback = 4000;
      };
    in
    {
      programs.kitty = {
        enable = true;
        # macOS: kitty-bin, upstream's notarised build. TCC ties grants (Full
        # Disk Access, Screen Recording, …) to the app's signature: the
        # ad-hoc-signed source build loses them on every rebuild, while
        # kitty-bin's bundle ID + team ID survive updates. It also ships
        # shell-integration/ and terminfo/.
        package = if pkgs.stdenv.isDarwin then pkgs.kitty-bin else pkgs.kitty;
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
          # On Hyprland a lone tiled kitty window saves "maximized" on close,
          # and the next one then opens maximised over its workspace. "yes" is
          # kitty's default, kept on macOS.
          remember_window_size = if pkgs.stdenv.isLinux then "no" else "yes";
          background_opacity = builtins.toString terminal.opacity;

          # Background
          background_image = "${../desktop/wallpapers/neko-kunoichi-v2.png}";
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
          # "no" is kitty's default. "yes" kept aerospace's alt+N workspace
          # bindings from working while kitty had focus. Cost: Option+key
          # types a character, so Alt shortcuts in terminal programs break;
          # kitty's own alt+ mappings below still fire.
          macos_option_as_alt = "no";
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
        }
        // lib.optionalAttrs pkgs.stdenv.isDarwin (
          # Pass cmd+1..9 through to the program, for herdr's focus_agent
          # (see terminals-herdr). kitty binds them to
          # first_window..ninth_window, unused as herdr owns the splits.
          # no_op means "stop intercepting", not "swallow".
          lib.genAttrs (map (n: "cmd+${toString n}") (lib.range 1 9)) (_: "no_op")
        );
      };
    };
}
