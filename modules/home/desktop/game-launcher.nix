# Full-screen game library: rofi with the rofi-games plugin, which finds
# installed games (Steam, Heroic, Lutris, Bottles, itch, Prism Launcher) and
# shows their box art as tiles over a blurred desktop. Coloured from the
# Crimson Ronin palette to match the Caelestia trial; works under any shell.
{
  config,
  inputs,
  lib,
  ...
}:
let
  font = config.flake.lib.theme.font.ui;
  c = (lib.importJSON "${inputs.crimson-ronin}/state/caelestia/scheme.json").colours;
in
{
  flake.modules.homeManager.desktop-game-launcher =
    {
      config,
      pkgs,
      osConfig,
      ...
    }:
    let
      rofi = pkgs.rofi.override { plugins = [ pkgs.rofi-games ]; };
      toml = pkgs.formats.toml { };

      # rofi-games starts a Steam game by running `steam steam://rungameid/…`
      # as rofi's child, and rofi exits at once. NixOS's steam runs bubblewrap
      # with --die-with-parent, so the sandbox was killed before it could pass
      # the URL to the running Steam. This steam, first on rofi's PATH,
      # detaches the real one into its own session, away from rofi.
      detachedSteam = pkgs.writeShellScriptBin "steam" ''
        exec ${pkgs.util-linux}/bin/setsid -f ${lib.getExe osConfig.programs.steam.package} "$@"
      '';

      # Crimson on the edge of the selected tile only, never as a fill.
      theme = pkgs.writeText "games-ronin.rasi" ''
        * {
            ink:              #${c.background}A0;
            tile:             #${c.surfaceContainerLow}B0;
            tile-selected:    #${c.surfaceContainerHigh}D0;
            edge:             #${c.surfaceContainerHighest};
            crimson:          #${c.primary};
            blade:            #${c.onSurface};
            mute:             #${c.subtext0};

            background-color: transparent;
            text-color:       @mute;
            font:             "${font} 12";
        }

        configuration {
            show-icons: true;
        }

        window {
            fullscreen:       true;
            transparency:     "real";
            background-color: @ink;
        }

        mainbox {
            children: [ inputbar, listview ];
            padding:  6% 8%;
            spacing:  48px;
        }

        inputbar {
            children:     [ prompt, entry ];
            expand:       false;
            spacing:      18px;
            padding:      0 0 14px 0;
            border:       0 0 1px 0;
            border-color: @edge;
        }

        prompt {
            text-color: @crimson;
            font:       "${font} Bold 12";
        }

        entry {
            text-color:        @blade;
            placeholder:       "search";
            placeholder-color: @mute;
            cursor:            text;
        }

        listview {
            columns:      8;
            spacing:      28px;
            flow:         horizontal;
            fixed-height: true;
            cycle:        false;
            scrollbar:    false;
        }

        element {
            orientation:      vertical;
            padding:          12px 10px;
            spacing:          12px;
            border:           1px;
            border-radius:    4px;
            border-color:     @edge;
            background-color: @tile;
            cursor:           pointer;
        }

        element selected {
            border-color:     @crimson;
            background-color: @tile-selected;
        }

        element-icon {
            size:   280px;
            cursor: inherit;
        }

        element-text {
            horizontal-align: 0.5;
            text-color:       inherit;
            cursor:           inherit;
        }

        element selected element-text {
            text-color: @blade;
        }
      '';

      # rofi's default is single click to select and double-click to launch.
      # Launch on a single click instead, by moving MousePrimary from
      # selecting to accepting (the pairing rofi(1) gives for this).
      game-launcher = pkgs.writeShellScriptBin "game-launcher" ''
        PATH=${detachedSteam}/bin:$PATH exec ${rofi}/bin/rofi -modi games -show games -theme ${theme} -display-games LIBRARY \
          -me-select-entry "" -me-accept-entry MousePrimary
      '';
    in
    {
      options.local.gameLauncher.entries = lib.mkOption {
        type = lib.types.listOf toml.type;
        default = [ ];
        description = ''
          Extra tiles for games rofi-games doesn't find, or overrides for ones
          it does (matched by title). Fields: title, launch_command,
          path_box_art, launch_env, hide (see the rofi-games README).
        '';
      };

      config = {
        home.packages = [ game-launcher ];

        # Both default to on, which prints "Title — Steam" in bold under every
        # tile.
        xdg.configFile."rofi-games/config.toml".source = toml.generate "config.toml" (
          {
            show_entry_source_text = false;
            use_bold_entry_title = false;
          }
          // lib.optionalAttrs (config.local.gameLauncher.entries != [ ]) {
            entries = config.local.gameLauncher.entries;
          }
        );

        wayland.windowManager.hyprland.settings = {
          # The window is translucent ink; the blur is what hides the desktop.
          layerrule = [ "blur on, match:namespace ^rofi$" ];
          bindd = [ "$mod, G, Game library, exec, game-launcher" ];
        };
      };
    };
}
