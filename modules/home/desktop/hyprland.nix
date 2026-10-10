{ config, lib, ... }:
let
  mocha = config.flake.lib.theme.catppuccin.mocha;
  # hyprland colours are rgba(RRGGBBAA) with no leading '#'.
  rgba = role: alpha: "rgba(${lib.removePrefix "#" role}${alpha})";

  # Shell code (bash or zsh) that points HYPRLAND_INSTANCE_SIGNATURE and
  # WAYLAND_DISPLAY at the newest running Hyprland, unless they already name a
  # running one. Hyprland leaves a directory under $XDG_RUNTIME_DIR/hypr for
  # every instance since boot, so the newest directory is not always the live
  # one. A terminal that outlives a Hyprland restart (herdr's panes take the
  # environment its server started with) keeps a dead instance's signature,
  # and hyprctl, and anything started from it, then cannot reach Hyprland.
  # Needs hyprctl, grep and head on PATH.
  liveHyprland = pkgs: ''
    live=$(hyprctl instances -j 2>/dev/null \
      | ${pkgs.jq}/bin/jq -r 'sort_by(-.time) | .[] | "\(.instance) \(.wl_socket)"')
    if [ -n "$live" ] && ! grep -q "^''${HYPRLAND_INSTANCE_SIGNATURE:-none} " <<<"$live"; then
      read -r HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY <<<"$(head -n 1 <<<"$live")"
      export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
    fi
  '';
in
{
  flake.lib.liveHyprland = liveHyprland;

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

      # Space in Thunar previews the selection in Sushi (installed in
      # system/nixos/hyprland.nix), like Nautilus and macOS's Quick Look.
      # Thunar has no preview hook, so it is a custom action bound to Space;
      # Thunar 4.20 gives a focused text entry the key first, so Space still
      # types in the location bar. thunar-quick-look-keys (below) makes the
      # arrow keys in the preview move Thunar's selection.
      quickLookId = "quick-look-sushi";
      quickLookCommand = "thunar-quick-look %f";
      quickLookAction = pkgs.writeText "thunar-quick-look.xml" ''
        <action>
          <icon>view-preview</icon>
          <name>Quick Look</name>
          <submenu></submenu>
          <unique-id>${quickLookId}</unique-id>
          <command>${quickLookCommand}</command>
          <description>Preview in Sushi: arrow keys move through the files, Space, Escape or Q closes it, F toggles fullscreen</description>
          <range></range>
          <patterns>*</patterns>
          <directories/>
          <audio-files/>
          <image-files/>
          <other-files/>
          <text-files/>
          <video-files/>
        </action>
      '';
      thunarQuickLook = pkgs.writeShellApplication {
        name = "thunar-quick-look";
        # hyprctl and sushi come from the system profile.
        runtimeInputs = with pkgs; [
          coreutils
          jq
        ];
        text = builtins.readFile ./hyprland/thunar-quick-look.sh;
      };
      thunarQuickLookKeys = pkgs.writeShellApplication {
        name = "thunar-quick-look-keys";
        # hyprctl comes from the system profile.
        runtimeInputs = with pkgs; [
          coreutils
          glib
        ];
        text = builtins.readFile ./hyprland/thunar-quick-look-keys.sh;
      };

      # Lets Loupe take images dragged from Thunar. Hyprland 0.56 tells a drop
      # target the action is MOVE as soon as a drag enters, if the source
      # allows it (Thunar allows COPY, MOVE and LINK), and ignores the
      # target's wl_data_offer.set_actions, so GTK 4 offers only MOVE and
      # Loupe, which takes only COPY, ignored the drop. With MOVE accepted too,
      # GTK still picks COPY when both are offered; Thunar deletes nothing.
      loupe = pkgs.loupe.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/widgets/image_window.ui \
            --replace-fail '<property name="actions">copy</property>' \
                           '<property name="actions">copy|move</property>'
        '';
      });
    in

    {
      # xdg-desktop-portal 1.17 no longer guesses which backend serves which
      # interface. modules/system/nixos/hyprland.nix sets this too, but
      # home-manager's xdg.portal has its own config and warns when it is
      # empty. "*" is the old behaviour: the first backend, alphabetically.
      xdg.portal.config.common.default = "*";

      # Without a named icon theme GTK asks for Adwaita, which is not
      # installed, and falls back to its built-in 16px icons: stretched
      # folders in Thunar, and none for images or PDFs. Carmine folders match
      # Crimson Ronin's reds. GTK 3 on Wayland reads the names from dconf
      # (org.gnome.desktop.interface), which home-manager writes alongside
      # settings.ini; without dconf, Thunar ignored settings.ini.
      #
      # Keep this the only Papirus-Dark installed: GTK 4 reads every copy in
      # XDG_DATA_DIRS at startup (twice for a GtkApplication), and a second
      # copy in the system profile added half a second to Loupe's start.
      gtk = {
        enable = true;
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme.override { color = "carmine"; };
        };
      };

      # The freedesktop user dirs (Documents, Downloads, …) in
      # ~/.config/user-dirs.dirs, so file pickers, browsers and screenshot
      # tools agree on them. The standard capitalised names match macOS, and
      # Pictures/Wallpapers is hard-coded elsewhere in this repo. Linux only:
      # macOS has its own fixed folders.
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        # Lowercase, the ghq root in apps-git; the module default is ~/Projects.
        projects = "${config.home.homeDirectory}/projects";
        # No desktop icons and no LAN file sharing on a tiling setup. null
        # leaves them out of user-dirs.dirs, so they are not created either.
        desktop = null;
        publicShare = null;
      };

      # Images open in Loupe (GNOME's image viewer). Unset, PNG and JPEG went
      # to Gradia, an editor that ambxst installs. The types are the MimeType
      # list from Loupe's desktop file.
      #
      # This makes ~/.config/mimeapps.list home-manager's, so an app's own
      # "set as default" can no longer write to it: defaults go here.
      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          lib.genAttrs [
            "image/apng"
            "image/avif"
            "image/bmp"
            "image/gif"
            "image/heic"
            "image/jp2"
            "image/jpeg"
            "image/jxl"
            "image/png"
            "image/qoi"
            "image/svg+xml"
            "image/svg+xml-compressed"
            "image/tiff"
            "image/vnd.microsoft.icon"
            "image/webp"
            "image/x-dds"
            "image/x-exr"
            "image/x-portable-anymap"
            "image/x-portable-bitmap"
            "image/x-portable-graymap"
            "image/x-portable-pixmap"
            "image/x-qoi"
            "image/x-tga"
            "image/x-win-bitmap"
            "image/x-xbitmap"
            "image/x-xpixmap"
          ] (_: "org.gnome.Loupe.desktop")
          // {
            # Claude Code's URL handler, which it can no longer register itself.
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
          };
      };

      # Adds the Quick Look action to Thunar's uca.xml and binds it to Space
      # in accels.scm, leaving the rest of both files to Thunar, which edits
      # them too. A missing uca.xml starts from Thunar's default; an action
      # with an out-of-date command is replaced. The shortcut is added only
      # while accels.scm has no line for the action, so a shortcut changed or
      # cleared in Thunar stays that way. Thunar reads both files at startup:
      # `thunar -q` after a change.
      home.activation.thunarQuickLook = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        thunar="${config.xdg.configHome}/Thunar"
        mkdir -p "$thunar"

        uca="$thunar/uca.xml"
        if [ ! -e "$uca" ]; then
          install -m600 ${pkgs.thunar}/etc/xdg/Thunar/uca.xml "$uca"
        fi
        if ! grep -qF '<command>${quickLookCommand}</command>' "$uca"; then
          tmp=$(mktemp)
          # Thunar writes <action>, </action> and </actions> on lines of
          # their own. Drops the old copy of this action, if there is one.
          ${pkgs.gawk}/bin/awk -v id='<unique-id>${quickLookId}</unique-id>' '
            $0 == "<action>" { block = $0; inside = 1; next }
            inside {
              block = block "\n" $0
              if ($0 == "</action>") {
                inside = 0
                if (index(block, id) == 0) print block
              }
              next
            }
            $0 != "</actions>" { print }
          ' "$uca" > "$tmp"
          { cat "$tmp" ${quickLookAction}; echo '</actions>'; } > "$uca"
          rm "$tmp"
        fi

        accels="$thunar/accels.scm"
        if ! grep -qF 'uca-action-${quickLookId}"' "$accels" 2>/dev/null; then
          echo '(gtk_accel_path "<Actions>/ThunarActions/uca-action-${quickLookId}" "space")' >> "$accels"
        fi
      '';

      wayland.windowManager.hyprland = {
        enable = true;
        package = null; # installed system-wide via programs.hyprland.enable

        # From home.stateVersion 26.05 this defaults to "lua", but `settings`
        # below is hyprlang: moving means rewriting it (docs/TODO.md).
        #
        # Hyprland 0.56 prefers ~/.config/hypr/hyprland.lua to hyprland.conf,
        # and writes a default hyprland.lua if it starts with no config at all
        # (say, after a failed activation). Delete a stray one: it shadows this.
        configType = "hyprlang";

        # Monitor layout, GPU selection (AQ_DRM_DEVICES) and multi-GPU
        # workarounds are per machine: each host file adds its own.
        settings = {
          # ── Autostart ──────────────────────────────────────────────
          # The desktop shell starts itself from its own module's
          # exec-once: a host imports desktop-ambxst or desktop-caelestia.

          # ── Monitors ───────────────────────────────────────────────
          # Hosts list their own monitors; mkAfter keeps this catch-all
          # below them.
          monitor = lib.mkAfter [
            ", preferred, auto, 1" # fallback for hotplug
          ];

          # ── Environment variables ──────────────────────────────────
          env = [
            # NVIDIA
            "LIBVA_DRIVER_NAME, nvidia"
            "__GLX_VENDOR_LIBRARY_NAME, nvidia"
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
            "col.active_border" = "${rgba mocha.mauve "ff"} ${rgba mocha.blue "ff"} 45deg";
            "col.inactive_border" = rgba mocha.surface0 "ff";
          };

          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 0.95;
            shadow = {
              enabled = true;
              range = 8;
              render_power = 2;
              color = rgba mocha.base "ee";
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
            vrr = 2; # adaptive sync in fullscreen apps/games
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
          };

          # ── Window rules ───────────────────────────────────────────
          # Sushi (Space in Thunar, above) sizes its window to the file, so it
          # floats. stay_focused keeps the arrow keys on it: otherwise focus
          # went to the window under the pointer whenever Sushi resized.
          windowrule = [
            "float on, center on, stay_focused on, match:class ^(org\\.gnome\\.NautilusPreviewer)$"
          ];

          # ── Keybindings ────────────────────────────────────────────
          "$mod" = "SUPER";

          bindd = [
            # Applications
            "$mod, Q, Open terminal (Kitty), exec, kitty"
            "$mod, C, Close active window, killactive"
            "$mod, E, File manager (Thunar), exec, thunar"
            "$mod, F, Toggle fullscreen, fullscreen"
            "$mod, V, Toggle floating, togglefloating"
            "$mod, M, Exit Hyprland, exit"

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

      # Arrow keys in Sushi's preview for Thunar (thunar-quick-look-keys.sh).
      # It also starts Sushi, which then stays running
      # (system/nixos/hyprland.nix), so even the first Space need not wait.
      # A unit rather than exec-once, so it starts after Hyprland has passed
      # WAYLAND_DISPLAY to the session bus, which Sushi needs.
      systemd.user.services.thunar-quick-look-keys = {
        Unit = {
          Description = "Arrow keys in Sushi's preview move Thunar's selection";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStartPre = "-${pkgs.systemd}/bin/busctl --user call org.freedesktop.DBus / org.freedesktop.DBus StartServiceByName su org.gnome.NautilusPreviewer 0";
          ExecStart = "${thunarQuickLookKeys}/bin/thunar-quick-look-keys";
          Restart = "always";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Before each prompt, follow Hyprland if the shell's instance has gone (see
      # liveHyprland), so commands typed after a Hyprland restart reach it. The
      # check is the one `hyprctl instances` makes: the instance's lock file
      # holds its pid, and signalling that pid with 0 tells whether it runs. It
      # uses builtins only (about 12 µs); hyprctl runs only for a dead instance
      # (about 8 ms). A shell without the variable (a text console, SSH) is left
      # alone. Programs already running keep their environment.
      programs.zsh.initContent = ''
        _follow_live_hyprland() {
          [[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] || return 0
          local lock=''${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock
          local pid live
          { read -r pid <"$lock" && kill -0 "$pid"; } 2>/dev/null && return 0
          ${liveHyprland pkgs}
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _follow_live_hyprland
      '';

      # Packages useful alongside Hyprland
      home.packages = [
        pkgs.brightnessctl
        loupe
        pkgs.playerctl
        pkgs.wl-clipboard
        hypr-cheatsheet
        thunarQuickLook
      ];
    };
}
