_: {
  flake.modules.homeManager.desktop-hyprland =
    { config, pkgs, ... }:
    let
      hypr-cheatsheet = pkgs.writeShellScriptBin "hypr-cheatsheet" ''
        hyprctl binds -j | ${pkgs.jq}/bin/jq -r '
          def decode_mods:
            . as $m |
            [
              if ($m / 64 | floor) % 2 == 1 then "Super" else empty end,
              if ($m / 4  | floor) % 2 == 1 then "Ctrl"  else empty end,
              if ($m / 8  | floor) % 2 == 1 then "Alt"   else empty end,
              if ($m / 1  | floor) % 2 == 1 then "Shift" else empty end
            ] | join(" + ");

          def clean_key:
            if . == "mouse:272" then "LMB"
            elif . == "mouse:273" then "RMB"
            elif . == "mouse_down" then "Scroll Down"
            elif . == "mouse_up" then "Scroll Up"
            elif . == "XF86AudioRaiseVolume" then "Vol+"
            elif . == "XF86AudioLowerVolume" then "Vol-"
            elif . == "XF86AudioMute" then "Mute"
            elif . == "XF86AudioPlay" then "Play"
            elif . == "XF86AudioNext" then "Next"
            elif . == "XF86AudioPrev" then "Prev"
            elif . == "XF86MonBrightnessUp" then "Bright+"
            elif . == "XF86MonBrightnessDown" then "Bright-"
            elif (. | length) == 1 then ascii_upcase
            else .
            end;

          def auto_desc:
            if .dispatcher == "exec" then .arg
            elif .dispatcher == "workspace" then "Switch to workspace " + .arg
            elif .dispatcher == "movetoworkspace" then "Move to workspace " + .arg
            elif .dispatcher == "movefocus" then "Focus " + ({"l":"left","r":"right","u":"up","d":"down"}[.arg] // .arg)
            elif .dispatcher == "swapwindow" then "Swap window " + ({"l":"left","r":"right","u":"up","d":"down"}[.arg] // .arg)
            elif .dispatcher == "fullscreen" then "Toggle fullscreen"
            elif .dispatcher == "togglefloating" then "Toggle floating"
            elif .dispatcher == "killactive" then "Close active window"
            elif .dispatcher == "exit" then "Exit Hyprland"
            elif .dispatcher == "togglespecialworkspace" then "Toggle scratchpad"
            elif .dispatcher == "movewindow" then "Move window (drag)"
            elif .dispatcher == "resizewindow" then "Resize window (drag)"
            else .dispatcher + (if .arg != "" then " " + .arg else "" end)
            end;

          def rpad($n): . + " " * ([$n - length, 1] | max);

          [ .[] |
            (.modmask | decode_mods) as $mods |
            ($mods + (if $mods != "" then " + " else "" end) + (.key | clean_key)) as $combo |
            (if (.description // "") != "" then .description else auto_desc end) as $desc |
            (($combo | rpad(28)) + $desc)
          ] |
          sort_by(
            if startswith("Super + Shift") then "01"
            elif startswith("Super + Ctrl") then "02"
            elif startswith("Super") then "00"
            elif startswith("Alt + Shift") then "04"
            elif startswith("Alt") then "03"
            else "05"
            end
          ) | .[]
        ' | ${pkgs.fuzzel}/bin/fuzzel --dmenu \
            --prompt "Keybindings > " \
            --width 60 \
            --lines 25
      '';
    in

    {
      wayland.windowManager.hyprland = {
        enable = true;
        package = null; # installed system-wide via programs.hyprland.enable

        # Source the dynamically generated DRM device config (created by
        # systemd service hyprland-drm-config in configuration.nix)
        extraConfig = ''
          source = /tmp/hypr-drm-devices.conf
        '';

        settings = {
          # ── Autostart ──────────────────────────────────────────────
          exec-once = [
            "ambxst" # bar, wallpaper, launcher, notifications
            "media-player-widget"
            "sh -c 'sleep 3 && hyprctl reload'" # reload config after ambxst startup to restore keybinds
          ];

          # ── Monitors ───────────────────────────────────────────────
          monitor = [
            "DP-1, 2560x1440@165, 1920x0, 1" # external monitor (right)
            "eDP-1, 1920x1080@144, 0x0, 1" # laptop (left, always at origin)
            ", preferred, auto, 1" # fallback for hotplug
          ];

          # ── Environment variables ──────────────────────────────────
          env = [
            # NVIDIA
            "LIBVA_DRIVER_NAME, nvidia"
            "__GLX_VENDOR_LIBRARY_NAME, nvidia"
            "NVD_BACKEND, direct"
            "AQ_FORCE_LINEAR_BLIT, 1" # force linear blitting for cross-GPU buffer copy (NVIDIA → Intel eDP)
            # Wayland toolkit hints
            "XDG_SESSION_TYPE, wayland"
            "QT_QPA_PLATFORM, wayland"
            "QT_WAYLAND_DISABLE_WINDOWDECORATION, 1"
            "SDL_VIDEODRIVER, wayland"
            "CLUTTER_BACKEND, wayland"
            "MOZ_ENABLE_WAYLAND, 1"
            # Cursor
            "XCURSOR_THEME, catppuccin-mocha-dark-cursors"
            "XCURSOR_SIZE, 24"
          ];

          # ── Input ──────────────────────────────────────────────────
          input = {
            repeat_rate = 35;
            repeat_delay = 300;
            accel_profile = "flat";
            touchpad = {
              natural_scroll = true;
              tap-to-click = true;
            };
          };

          gesture = [
            "3, horizontal, workspace"
          ];

          # ── Look & feel ────────────────────────────────────────────
          general = {
            gaps_in = 4;
            gaps_out = 8;
            border_size = 2;
            "col.active_border" = "rgba(cba6f7ff) rgba(89b4faff) 45deg"; # mauve → blue
            "col.inactive_border" = "rgba(313244ff)"; # surface0
          };

          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 0.95;
            shadow = {
              enabled = true;
              range = 8;
              render_power = 2;
              color = "rgba(1e1e2eee)";
            };
            blur = {
              enabled = true;
              size = 6;
              passes = 2;
              new_optimizations = true;
            };
          };

          animations = {
            enabled = true;
            bezier = [ "ease, 0.25, 0.1, 0.25, 1" ];
            animation = [
              "windows, 1, 4, ease, slide"
              "windowsOut, 1, 4, ease, slide"
              "fade, 1, 4, ease"
              "workspaces, 1, 4, ease, slide"
            ];
          };

          render = {
            cm_enabled = false;
            new_render_scheduling = true; # dynamic triple buffering for high refresh rates
          };

          misc = {
            vfr = true;
            vrr = 2; # adaptive sync in fullscreen apps/games
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
          };

          # ── Keybindings ────────────────────────────────────────────
          "$mod" = "SUPER";

          bindd = [
            # Applications
            "$mod, Q, Open terminal (Kitty), exec, kitty"
            "$mod, C, Close active window, killactive"
            "$mod, R, App launcher (Fuzzel), exec, fuzzel"
            "$mod, F, Toggle fullscreen, fullscreen"
            "$mod, V, Toggle floating, togglefloating"
            "$mod, M, Exit Hyprland, exit"
            "$mod, slash, Keybinding cheatsheet, exec, hypr-cheatsheet"

            # Focus (ALT + arrow keys)
            "ALT, Left, Focus window left, movefocus, l"
            "ALT, Right, Focus window right, movefocus, r"
            "ALT, Up, Focus window up, movefocus, u"
            "ALT, Down, Focus window down, movefocus, d"

            # Swap windows (ALT + SHIFT + arrow keys)
            "ALT SHIFT, Left, Swap window left, swapwindow, l"
            "ALT SHIFT, Right, Swap window right, swapwindow, r"
            "ALT SHIFT, Up, Swap window up, swapwindow, u"
            "ALT SHIFT, Down, Swap window down, swapwindow, d"

            # Workspaces
            "$mod, 1, Switch to workspace 1, workspace, 1"
            "$mod, 2, Switch to workspace 2, workspace, 2"
            "$mod, 3, Switch to workspace 3, workspace, 3"
            "$mod, 4, Switch to workspace 4, workspace, 4"
            "$mod, 5, Switch to workspace 5, workspace, 5"
            "$mod, 6, Switch to workspace 6, workspace, 6"
            "$mod, 7, Switch to workspace 7, workspace, 7"
            "$mod, 8, Switch to workspace 8, workspace, 8"
            "$mod, 9, Switch to workspace 9, workspace, 9"
            "$mod, 0, Switch to workspace 10, workspace, 10"

            # Move window to workspace
            "$mod SHIFT, 1, Move window to workspace 1, movetoworkspace, 1"
            "$mod SHIFT, 2, Move window to workspace 2, movetoworkspace, 2"
            "$mod SHIFT, 3, Move window to workspace 3, movetoworkspace, 3"
            "$mod SHIFT, 4, Move window to workspace 4, movetoworkspace, 4"
            "$mod SHIFT, 5, Move window to workspace 5, movetoworkspace, 5"
            "$mod SHIFT, 6, Move window to workspace 6, movetoworkspace, 6"
            "$mod SHIFT, 7, Move window to workspace 7, movetoworkspace, 7"
            "$mod SHIFT, 8, Move window to workspace 8, movetoworkspace, 8"
            "$mod SHIFT, 9, Move window to workspace 9, movetoworkspace, 9"
            "$mod SHIFT, 0, Move window to workspace 10, movetoworkspace, 10"

            # Scratchpad
            "$mod, S, Toggle scratchpad, togglespecialworkspace, magic"
            "$mod SHIFT, S, Move window to scratchpad, movetoworkspace, special:magic"

            # Scroll through workspaces
            "$mod, mouse_down, Next workspace (scroll), workspace, e+1"
            "$mod, mouse_up, Previous workspace (scroll), workspace, e-1"
          ];

          # Media / brightness keys (repeat on hold)
          binddel = [
            ", XF86AudioRaiseVolume, Volume up, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, Volume down, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ", XF86MonBrightnessUp, Brightness up, exec, brightnessctl s 5%+"
            ", XF86MonBrightnessDown, Brightness down, exec, brightnessctl s 5%-"
          ];

          # Media controls (work on lock screen)
          binddl = [
            ", XF86AudioMute, Toggle mute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ", XF86AudioPlay, Play/Pause media, exec, playerctl play-pause"
            ", XF86AudioNext, Next track, exec, playerctl next"
            ", XF86AudioPrev, Previous track, exec, playerctl previous"
          ];

          # Move/resize with mouse
          binddm = [
            "$mod, mouse:272, Move window (drag), movewindow"
            "$mod, mouse:273, Resize window (drag), resizewindow"
          ];
        };
      };

      # Packages useful alongside Hyprland
      home.packages = [
        pkgs.brightnessctl
        pkgs.playerctl
        pkgs.wl-clipboard
        hypr-cheatsheet
      ];
    };
}
