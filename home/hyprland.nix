{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # installed system-wide via programs.hyprland.enable

    settings = {
      # ── Autostart ──────────────────────────────────────────────
      exec-once = [
        "ambxst" # bar, wallpaper, launcher, notifications
        "media-player-widget"
      ];

      exec = [
        "sh -c 'echo \"--- reload $(date) ---\" >> /tmp/hypr-debug.log && echo \"ambxst pid: $(cat /tmp/ambxst.pid 2>/dev/null)\" >> /tmp/hypr-debug.log && kill -0 $(cat /tmp/ambxst.pid 2>/dev/null) 2>> /tmp/hypr-debug.log && echo \"ambxst: alive\" >> /tmp/hypr-debug.log || echo \"ambxst: dead\" >> /tmp/hypr-debug.log && hyprctl clients >> /tmp/hypr-debug.log 2>&1 && hyprctl layers >> /tmp/hypr-debug.log 2>&1'"
      ];

      # ── Monitors ───────────────────────────────────────────────
      monitor = [
        "DP-1, 2560x1440@165, 0x0, 1"  # external monitor (main)
        "eDP-1, 1920x1080@144, auto-left, 1" # laptop to the left
      ];

      # ── Environment variables ──────────────────────────────────
      env = [
        # Use NVIDIA as primary renderer (card1), Intel as secondary for eDP-1 output
        "AQ_DRM_DEVICES, /dev/dri/card1:/dev/dri/card2"
        # NVIDIA
        "LIBVA_DRIVER_NAME, nvidia"
        "__GLX_VENDOR_LIBRARY_NAME, nvidia"
        "GBM_BACKEND, nvidia-drm"
        "NVD_BACKEND, direct"
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
        repeat_delay = 200;
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

      bind = [
        # Applications
        "$mod, Q, exec, kitty"
        "$mod, C, killactive"
        "$mod, R, exec, fuzzel"
        "$mod, F, fullscreen"
        "$mod, V, togglefloating"
        "$mod, M, exit"

        # Focus (ALT + arrow keys)
        "ALT, Left, movefocus, l"
        "ALT, Right, movefocus, r"
        "ALT, Up, movefocus, u"
        "ALT, Down, movefocus, d"

        # Swap windows (ALT + SHIFT + arrow keys)
        "ALT SHIFT, Left, swapwindow, l"
        "ALT SHIFT, Right, swapwindow, r"
        "ALT SHIFT, Up, swapwindow, u"
        "ALT SHIFT, Down, swapwindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Scratchpad
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      # Media / brightness keys (work without mod, repeat on hold)
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl s 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Move/resize with mouse
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Packages useful alongside Hyprland
  home.packages = with pkgs; [
    brightnessctl
    playerctl
    wl-clipboard
  ];
}
