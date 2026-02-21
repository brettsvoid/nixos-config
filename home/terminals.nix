{ config, pkgs, lib, ... }:

let
  # Shared terminal preferences — single source of truth
  terminal = {
    font = {
      family = "FiraCode Nerd Font Mono";
      size = 13;
    };
    opacity = 0.95;
    padding = 8;
    scrollback = 10000;
    theme = "catppuccin-mocha";
  };
in
{
  # ─── Kitty ──────────────────────────────────────────────────────────
  programs.kitty = {
    enable = true;
    font = {
      name = terminal.font.family;
      size = terminal.font.size;
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
      enabled_layouts = "Tall,Fat,Grid,Stack";
      window_border_width = 0;
      window_margin_width = 0;
      window_padding_width = terminal.padding;
      single_window_margin_width = 0;
      single_window_padding_width = terminal.padding;
      active_border_color = "none";
      inactive_text_alpha = "0.4";
      dim_opacity = "0.4";
      background_opacity = builtins.toString terminal.opacity;

      # Background
      background_image = "/home/brett/.config/kitty/anime-neko-ninja-wallpaper-rework.png";
      background_image_layout = "cscaled";
      background_image_linear = "yes";
      background_tint = "0.95";
      background_tint_gaps = "1";

      # Wayland / Linux
      linux_display_server = "wayland";
      wayland_titlebar_color = "background";
      hide_window_decorations = "yes";

      # Bell
      enable_audio_bell = "no";
      visual_bell_duration = 0;

      # Tab bar
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_bar_edge = "bottom";
      tab_bar_min_tabs = 2;
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
    };
  };

  # ─── Ghostty ────────────────────────────────────────────────────────
  # Ghostty doesn't have a dedicated home-manager module yet in most
  # channels, so we manage it via xdg.configFile + the package.
  home.packages = [ pkgs.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    # ─── Theme ─────────────────────────────────────────────────────────
    theme = "Catppuccin Mocha"

    # ─── Font ──────────────────────────────────────────────────────────
    font-family = "${terminal.font.family}"
    font-size = ${toString terminal.font.size}
    font-feature = calt
    font-feature = liga

    # ─── Cursor ────────────────────────────────────────────────────────
    cursor-style = bar
    cursor-style-blink = true

    # ─── Window ────────────────────────────────────────────────────────
    window-padding-x = ${toString terminal.padding}
    window-padding-y = ${toString terminal.padding}
    window-padding-balance = true
    window-decoration = false
    window-inherit-working-directory = true

    # ─── Background ────────────────────────────────────────────────────
    background-opacity = ${builtins.toString terminal.opacity}
    background-image = /home/brett/.config/ghostty/anime_style_sheet_ghost_outside_town.jpg
    background-image-fit = cover
    background-image-opacity = 0.05

    # ─── Behaviour ─────────────────────────────────────────────────────
    mouse-hide-while-typing = true
    shell-integration = detect
    shell-integration-features = cursor,sudo,title
    scrollback-limit = ${toString terminal.scrollback}
    clipboard-read = allow
    clipboard-write = allow
    copy-on-select = clipboard

    # ─── GTK / Wayland ─────────────────────────────────────────────────
    gtk-single-instance = true

    # ─── Keybindings ───────────────────────────────────────────────────
    keybind = ctrl+shift+d=new_split:right
    keybind = ctrl+shift+e=new_split:down
    keybind = ctrl+shift+enter=new_window

    keybind = ctrl+shift+h=goto_split:left
    keybind = ctrl+shift+l=goto_split:right
    keybind = ctrl+shift+k=goto_split:top
    keybind = ctrl+shift+j=goto_split:bottom

    keybind = ctrl+shift+t=new_tab
    keybind = ctrl+shift+1=goto_tab:1
    keybind = ctrl+shift+2=goto_tab:2
    keybind = ctrl+shift+3=goto_tab:3
    keybind = ctrl+shift+4=goto_tab:4
    keybind = ctrl+shift+5=goto_tab:5

    keybind = ctrl+shift+z=toggle_split_zoom
    keybind = ctrl+shift+f=toggle_fullscreen
    keybind = ctrl+shift+comma=reload_config
  '';
}
