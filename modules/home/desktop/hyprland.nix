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
  # Entries for home-manager's Lua settings (configType = "lua"): `_args`
  # renders as a call with several arguments, mkLuaInline as raw Lua.
  hypr =
    let
      inline = lib.generators.mkLuaInline;
      toLua = lib.generators.toLua { };
    in
    {
      # A dispatcher, e.g. dsp "window.close()" for hl.dsp.window.close().
      dsp = expr: inline "hl.dsp.${expr}";
      exec = cmd: inline "hl.dsp.exec_cmd(${toLua cmd})";
      global = name: inline "hl.dsp.global(${toLua name})";
      # settings.bind entry: hl.bind(keys, dispatcher, opts).
      bind = keys: dispatcher: opts: {
        _args = [
          keys
          dispatcher
          opts
        ];
      };
      env = name: value: {
        _args = [
          name
          value
        ];
      };
      # settings.on entry that runs a command once at login (exec-once).
      onStart = cmd: {
        _args = [
          "hyprland.start"
          (inline "function() hl.exec_cmd(${toLua cmd}) end")
        ];
      };
    };
in
{
  flake.lib = { inherit hypr liveHyprland; };

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

          def rpad($n): . + " " * ([$n - length, 1] | max);

          [ .[] |
            (.modmask | decode_mods) as $mods |
            ($mods + (if $mods != "" then " + " else "" end) + (.key | clean_key)) as $combo |
            # Lua binds report their dispatcher as "HL.Dispatcher(exec_cmd)", with no argument.
            (if (.description // "") != "" then .description else .dispatcher end) as $desc |
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

      xdg = {
        # xdg-desktop-portal 1.17 no longer guesses which backend serves which
        # interface. modules/system/nixos/hyprland.nix sets this too, but
        # home-manager's xdg.portal has its own config and warns when it is
        # empty. "*" is the old behaviour: the first backend, alphabetically.
        portal.config.common.default = "*";

        # The freedesktop user dirs (Documents, Downloads, …) in
        # ~/.config/user-dirs.dirs, so file pickers, browsers and screenshot
        # tools agree on them. The standard capitalised names match macOS, and
        # Pictures/Wallpapers is hard-coded elsewhere in this repo. Linux only:
        # macOS has its own fixed folders.
        userDirs = {
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
        mimeApps = {
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

        # Hyprland 0.57 reads only hyprland.lua. Each settings.<name> entry
        # renders as an hl.<name>(...) call; flake.lib.hypr builds the
        # entries that take more than one argument.
        configType = "lua";

        # Monitor layout, GPU selection (AQ_DRM_DEVICES) and multi-GPU
        # workarounds are per machine: each host file adds its own.
        settings = {
          # ── Autostart ──────────────────────────────────────────────
          # The desktop shell starts itself from its own module's
          # hypr.onStart: a host imports desktop-ambxst or desktop-caelestia.

          # ── Monitors ───────────────────────────────────────────────
          # Hosts list their own monitors; mkAfter keeps this catch-all
          # below them.
          monitor = lib.mkAfter [
            {
              output = ""; # fallback for hotplug
              mode = "preferred";
              position = "auto";
              scale = 1;
            }
          ];

          # ── Environment variables ──────────────────────────────────
          env = lib.mapAttrsToList hypr.env {
            # NVIDIA
            LIBVA_DRIVER_NAME = "nvidia";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            NVD_BACKEND = "direct";
            # Wayland toolkit hints
            XDG_SESSION_TYPE = "wayland";
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            SDL_VIDEODRIVER = "wayland";
            CLUTTER_BACKEND = "wayland";
            MOZ_ENABLE_WAYLAND = "1";
            # Cursor
            XCURSOR_THEME = "catppuccin-mocha-dark-cursors";
            XCURSOR_SIZE = "24";
          };

          gesture = [
            {
              fingers = 3;
              direction = "horizontal";
              action = "workspace";
            }
          ];

          config = {
            # ── Input ────────────────────────────────────────────────
            input = {
              repeat_rate = 35;
              repeat_delay = 300;
              accel_profile = "flat";
              touchpad = {
                natural_scroll = true;
                tap_to_click = true;
              };
            };

            # ── Look & feel ──────────────────────────────────────────
            general = {
              gaps_in = 4;
              gaps_out = 8;
              border_size = 2;
              col = {
                active_border = {
                  colors = [
                    (rgba mocha.mauve "ff")
                    (rgba mocha.blue "ff")
                  ];
                  angle = 45;
                };
                inactive_border = rgba mocha.surface0 "ff";
              };
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

            animations.enabled = true;

            render = {
              cm_enabled = false;
              new_render_scheduling = true; # dynamic triple buffering for high refresh rates
            };

            misc = {
              vrr = 2; # adaptive sync in fullscreen apps/games
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
            };

            # Hyprland writes its own lines to hyprland.log only with this off.
            # Without them the 14 Nov lock that ignored keys after a wake left no
            # trace of what Hyprland did.
            debug.disable_logs = false;
          };

          curve = [
            {
              _args = [
                "ease"
                {
                  type = "bezier";
                  points = [
                    [
                      0.25
                      0.1
                    ]
                    [
                      0.25
                      1
                    ]
                  ];
                }
              ];
            }
          ];
          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 4;
              bezier = "ease";
              style = "slide";
            }
            {
              leaf = "windowsOut";
              enabled = true;
              speed = 4;
              bezier = "ease";
              style = "slide";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 4;
              bezier = "ease";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 4;
              bezier = "ease";
              style = "slide";
            }
          ];

          # ── Window rules ───────────────────────────────────────────
          # Sushi (Space in Thunar, above) sizes its window to the file, so it
          # floats. stay_focused keeps the arrow keys on it: otherwise focus
          # went to the window under the pointer whenever Sushi resized.
          window_rule = [
            {
              match.class = "^(org\\.gnome\\.NautilusPreviewer)$";
              float = true;
              center = true;
              stay_focused = true;
            }
          ];

          # ── Keybindings ────────────────────────────────────────────
          bind =
            with hypr;
            [
              # Applications
              (bind "SUPER + Q" (exec "kitty") { description = "Open terminal (Kitty)"; })
              (bind "SUPER + C" (dsp "window.close()") { description = "Close active window"; })
              (bind "SUPER + E" (exec "thunar") { description = "File manager (Thunar)"; })
              (bind "SUPER + F" (dsp "window.fullscreen()") { description = "Toggle fullscreen"; })
              (bind "SUPER + V" (dsp ''window.float({ action = "toggle" })'') {
                description = "Toggle floating";
              })
              (bind "SUPER + M" (dsp "exit()") { description = "Exit Hyprland"; })
              # The session locks on the way down (logind's Lock signal).
              (bind "SUPER + SHIFT + L" (exec "systemctl suspend") { description = "Suspend"; })
            ]
            # Focus (ALT + arrow keys), swap windows (ALT + SHIFT + arrow keys)
            ++
              lib.concatMap
                (
                  dir:
                  let
                    key = lib.toSentenceCase dir;
                  in
                  [
                    (bind "ALT + ${key}" (dsp ''focus({ direction = "${dir}" })'') {
                      description = "Focus window ${dir}";
                    })
                    (bind "ALT + SHIFT + ${key}" (dsp ''window.swap({ direction = "${dir}" })'') {
                      description = "Swap window ${dir}";
                    })
                  ]
                )
                [
                  "left"
                  "right"
                  "up"
                  "down"
                ]
            # Workspaces, and moving a window to one
            ++ lib.concatMap (
              ws:
              let
                key = toString (lib.mod ws 10);
              in
              [
                (bind "SUPER + ${key}" (dsp "focus({ workspace = ${toString ws} })") {
                  description = "Switch to workspace ${toString ws}";
                })
                (bind "SUPER + SHIFT + ${key}" (dsp "window.move({ workspace = ${toString ws} })") {
                  description = "Move window to workspace ${toString ws}";
                })
              ]
            ) (lib.range 1 10)
            ++ [
              # Scratchpad
              (bind "SUPER + S" (dsp ''workspace.toggle_special("magic")'') {
                description = "Toggle scratchpad";
              })
              (bind "SUPER + SHIFT + S" (dsp ''window.move({ workspace = "special:magic" })'') {
                description = "Move window to scratchpad";
              })

              # Scroll through workspaces
              (bind "SUPER + mouse_down" (dsp ''focus({ workspace = "e+1" })'') {
                description = "Next workspace (scroll)";
              })
              (bind "SUPER + mouse_up" (dsp ''focus({ workspace = "e-1" })'') {
                description = "Previous workspace (scroll)";
              })

              # Media / brightness keys (repeat on hold, work on the lock screen)
              (bind "XF86AudioRaiseVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") {
                description = "Volume up";
                repeating = true;
                locked = true;
              })
              (bind "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") {
                description = "Volume down";
                repeating = true;
                locked = true;
              })
              (bind "XF86MonBrightnessUp" (exec "brightnessctl s 5%+") {
                description = "Brightness up";
                repeating = true;
                locked = true;
              })
              (bind "XF86MonBrightnessDown" (exec "brightnessctl s 5%-") {
                description = "Brightness down";
                repeating = true;
                locked = true;
              })

              # Media controls (work on the lock screen)
              (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
                description = "Toggle mute";
                locked = true;
              })
              (bind "XF86AudioPlay" (exec "playerctl play-pause") {
                description = "Play/Pause media";
                locked = true;
              })
              (bind "XF86AudioNext" (exec "playerctl next") {
                description = "Next track";
                locked = true;
              })
              (bind "XF86AudioPrev" (exec "playerctl previous") {
                description = "Previous track";
                locked = true;
              })

              # Move/resize with mouse
              (bind "SUPER + mouse:272" (dsp "window.drag()") {
                description = "Move window (drag)";
                mouse = true;
              })
              (bind "SUPER + mouse:273" (dsp "window.resize()") {
                description = "Resize window (drag)";
                mouse = true;
              })
            ];
        };
      };

      # Hyprland writes its stock hyprland.lua if it ever starts with no
      # config (say, after a failed activation). That file is never ours, so
      # replace it rather than fail the activation on it.
      xdg.configFile."hypr/hyprland.lua".force = true;

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
        pkgs.mpv
        pkgs.playerctl
        pkgs.wl-clipboard
        hypr-cheatsheet
        thunarQuickLook
      ];
    };
}
