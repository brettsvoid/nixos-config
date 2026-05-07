# Ghostty doesn't yet have a first-class home-manager module on every channel,
# so we manage it via xdg.configFile + the package directly.
#
# On Darwin the package install is skipped — nixpkgs.ghostty currently
# blocks aarch64-darwin, so we let the homebrew cask own the binary and
# nix only manages the config file.
_: {
  flake.modules.homeManager.terminals-ghostty =
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
        scrollback = 10000;
      };
    in
    {
      home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty ];

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
        background-image = ${config.home.homeDirectory}/.config/ghostty/anime_style_sheet_ghost_outside_town.jpg
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
    };
}
