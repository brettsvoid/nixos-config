# Custom Quickshell-based bar with matugen-generated theme. Coexists with
# ambxst (the prior bar) and, where desktop-caelestia is imported, the
# Caelestia trial; `toggle-shell` switches between them.
{ inputs, config, ... }:
let
  inherit (config.flake.lib) repoDir liveHyprland;
in
{
  flake.modules.homeManager.desktop-custom-shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # The audio visualiser's QML plugin (shell-native: Rust, cxx-qt), `import
      # CustomShell.Native`. cxx-qt finds Qt through qmake, which has to see Qt's QML
      # module as well, and qtbase's setup hook points QMAKE at its own, so it is set
      # again before the build. cxx-qt links with lld; pipewire-rs needs bindgen.
      shell-native = pkgs.rustPlatform.buildRustPackage {
        pname = "shell-native";
        version = "0.1.0";
        src = ./shell-native;
        cargoLock.lockFile = ./shell-native/Cargo.lock;
        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.lld
          pkgs.rustPlatform.bindgenHook
        ];
        buildInputs = [
          pkgs.qt6.qtbase
          pkgs.qt6.qtdeclarative
          pkgs.pipewire
        ];
        dontWrapQtApps = true;
        preBuild = ''
          export QMAKE=${pkgs.qt6.env "qt-cxxqt" [ pkgs.qt6.qtdeclarative ]}/bin/qmake
        '';
        # The test binary links Qt and PipeWire but has no rpath to them.
        preCheck = ''
          export LD_LIBRARY_PATH=${
            lib.makeLibraryPath [
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.pipewire
              pkgs.stdenv.cc.cc.lib
            ]
          }
        '';
        # The library, renamed as the module's qmldir names it, beside its qmldir.
        installPhase = ''
          runHook preInstall
          dir=$out/lib/qt-6/qml/CustomShell/Native
          mkdir -p $dir
          module=$(find target -path '*qml_modules/CustomShell/Native' -type d | head -n 1)
          cp "$module/qmldir" "$module/plugin.qmltypes" $dir/
          cp "$(find target -name libshell_native.so -path '*release*' | head -n 1)" $dir/libCustomShell_Native.so
          runHook postInstall
        '';
        # Linked as a plugin, it gets no run path; give it the Qt and PipeWire it was
        # built against (the same Qt as Quickshell's).
        postFixup = ''
          patchelf --add-rpath ${
            lib.makeLibraryPath [
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.pipewire
              pkgs.stdenv.cc.cc.lib
            ]
          } $out/lib/qt-6/qml/CustomShell/Native/libCustomShell_Native.so
        '';
      };

      # Quickshell with the shell's own QML modules on its import path.
      qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.withModules [
        shell-native
      ];

      # Qt loads shaders as .qsb, so each one under quickshell/shaders is compiled
      # here and by qs-dev. A shader that does not compile fails the build. Qt's
      # OpenGL renderer gets an OpenGL ES 3.2 context on NVIDIA under Wayland, and the
      # only ES variant --qt6 bakes (100 es) has no array constructors, which the frame
      # shader uses: so 300 es, and 330 for a desktop OpenGL context.
      compileShaders = dir: ''
        for shader in "${dir}"/shaders/*.frag "${dir}"/shaders/*.vert; do
          [ -e "$shader" ] || continue
          ${pkgs.qt6.qtshadertools}/bin/qsb --glsl "300 es,330" -o "$shader.qsb" "$shader" || exit 1
        done
      '';

      # Quickshell only knows hicolor unless told the icon theme; use the GTK one, so
      # the launcher's icons match every other app's.
      iconThemeEnv = lib.optionalString (
        config.gtk.iconTheme != null
      ) "export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}";

      # The pomodoro's phase-end sound (services/Pomodoro.qml), played with pw-play. By
      # store path, so the sound theme is always installed with the shell.
      alarmSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";

      # The environment the shell runs in, for toggle-shell and qs-dev. MangoHud is on
      # for the whole session (profile-gaming), and its Vulkan layer loads into the
      # shell too, where its NVIDIA thread kept about 28% of a core busy. OpenGL, not
      # Vulkan: Qt's Vulkan renderer costs far more VRAM per screen-sized window, and
      # the shell has two on each screen. On 2560x1440 and 1080x1920 the shell held
      # 560 MiB on Vulkan and 242 MiB on OpenGL (nvidia-smi, 22 Oct 2026).
      qsEnv = ''
        qs_env() {
          export QSG_RHI_BACKEND=opengl
          ${iconThemeEnv}
          export CUSTOM_SHELL_ALARM_SOUND=${alarmSound}
          export DISABLE_MANGOHUD=1
        }
      '';

      # The commands' scripts are in ./custom-shell, each described at its top; the Nix
      # values one needs go before it as variables. No bash options: the scripts handle
      # failures themselves.
      script =
        name: runtimeInputs: preamble:
        pkgs.writeShellApplication {
          inherit name runtimeInputs;
          bashOptions = [ ];
          text = preamble + builtins.readFile ./custom-shell/${name}.sh;
        };

      custom-shell-or = script "custom-shell-or" [ pkgs.jq ] "";
      # Drives the running shell over Quickshell's IPC (quickshell/ipc/Ipc.qml).
      custom-shell = script "custom-shell" [ ] "qs=${qsPkg}/bin/qs\n";
      lock-recover = script "lock-recover" [
        pkgs.coreutils
        pkgs.jq
      ] "";

      # Statistics for the dashboard's performance tab: a JSON line a second while the
      # tab shows (shell-stats/src/main.rs).
      shell-stats = pkgs.rustPlatform.buildRustPackage {
        pname = "shell-stats";
        version = "0.1.0";
        src = ./shell-stats;
        cargoLock.lockFile = ./shell-stats/Cargo.lock;
        meta.mainProgram = "shell-stats";
      };

      wallpaper-thumbnails = script "wallpaper-thumbnails" [
        pkgs.coreutils
        pkgs.imagemagick
      ] "";

      # The shell in a headless sway, apart from the desktop, for tests and for the
      # load check in shellConfig.
      qs-test =
        script "qs-test"
          [
            pkgs.coreutils
            pkgs.dbus
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.python3
          ]
          ''
            qs=${qsPkg}/bin/qs
            sway=${pkgs.sway-unwrapped}/bin/sway
            dbus_config=${pkgs.dbus}/share/dbus-1/session.conf
            fake_hyprland=${./custom-shell/fake-hyprland.py}
            alarm_sound=${alarmSound}
            default_config="$HOME/${repoDir}/modules/home/desktop/quickshell"
            compile_shaders() {
              ${compileShaders "$1"}
            }
          '';

      # The shell must load, without a QML error or warning, or the build fails here,
      # before a rebuild restarts the running shell on it. It loads with a theme made
      # from a fixed colour, as the build has no wallpaper.
      shellConfig = pkgs.runCommand "custom-shell-config" { } ''
        cp -r ${./quickshell} $out
        chmod -R u+w $out
        ${compileShaders "$out"}
        export HOME=$TMPDIR
        ${pkgs.matugen}/bin/matugen color hex '#b03a3a' -m dark -c ${matugenConfig} >/dev/null
        ${qs-test}/bin/qs-test -c $out -t 3 --check
      '';

      toggle-shell = script "toggle-shell" [ pkgs.jq ] ''
        qs=${qsPkg}/bin/qs
        ${qsEnv}
        # A shell started from a terminal that outlived a Hyprland restart cannot reach
        # Hyprland's socket, so it does not know which monitor is focused and no drawer
        # opens.
        ${liveHyprland pkgs}
      '';

      matugenDir = ./quickshell/matugen;

      # Where the custom shell is the session's shell, its theme is the desktop's: GTK
      # apps take the palette and follow light or dark too. Elsewhere another shell
      # themes them (ambxst on the laptop). The window borders are the shell's own
      # (quickshell/theme/WindowBorders.qml), set while it runs.
      themeApps = config.local.customShell.atLogin;

      # The shell's colours, and with themeApps GTK's: libadwaita and adw-gtk3 draw with
      # the named colours in gtk.css, which GTK 3 and 4 each read from their own folder.
      matugenConfig = (pkgs.formats.toml { }).generate "matugen.toml" (
        lib.recursiveUpdate (lib.importTOML ./quickshell/matugen/config.toml) {
          templates = {
            custom-shell.input_path = "${matugenDir}/colors.json";
          }
          // lib.optionalAttrs themeApps {
            gtk3 = {
              input_path = "${matugenDir}/gtk.css";
              output_path = "~/.config/gtk-3.0/gtk.css";
            };
            gtk4 = {
              input_path = "${matugenDir}/gtk.css";
              output_path = "~/.config/gtk-4.0/gtk.css";
            };
          };
        }
      );

      generate-theme =
        script "generate-theme"
          [
            pkgs.coreutils
            pkgs.dconf
            pkgs.findutils
            pkgs.jq
            pkgs.matugen
          ]
          ''
            matugen_config=${matugenConfig}
            theme_apps=${lib.boolToString themeApps}
          '';

      qs-dev = pkgs.writeShellScriptBin "qs-dev" ''
        SHELL_DIR="''${1:-$HOME/${repoDir}/modules/home/desktop/quickshell}"
        if [ ! -f "$SHELL_DIR/shell.qml" ]; then
          echo "Error: $SHELL_DIR/shell.qml not found"
          exit 1
        fi
        ${compileShaders "$SHELL_DIR"}
        echo "Starting quickshell from $SHELL_DIR (Ctrl+C to stop)"
        echo "Runs ON TOP of ambxst -- nothing killed."
        ${liveHyprland pkgs}
        ${qsEnv}
        qs_env
        exec ${qsPkg}/bin/qs -p "$SHELL_DIR"
      '';
    in
    {
      # Starting values for the shell's settings (quickshell/config/Settings.qml), so a
      # fresh install or another host starts with them. The shell uses each one unless
      # the user has chosen otherwise in the settings window, whose choices stay in
      # ~/.config/custom-shell/settings.json; resetting a setting there returns it to
      # the value here. A value the shell does not know, or of the wrong type, is
      # ignored. `screens` holds values for one screen, by its description or connector,
      # for the settings marked perScreen.
      options.local.customShell.settings = lib.mkOption {
        inherit (pkgs.formats.json { }) type;
        default = { };
        example = {
          appearance = {
            fontFamily = "Inter";
            textScale = 1.1;
            frameThickness = 6;
          };
          screens."Dell Inc. Dell AW2518H #ASO0Wsxq3xLd".bar.edge = "left";
        };
        description = "The shell's settings by the same keys as its settings file, as starting values the settings window can override.";
      };

      # The session's shell from login. Caelestia and ambxst stay installed on a host
      # that imports them, for `toggle-shell caelestia` or `toggle-shell ambxst`, but
      # no longer start at login (caelestia.nix, ambxst.nix).
      options.local.customShell.atLogin = lib.mkEnableOption "the custom shell as the session's shell, started at login";

      config = {
        home.packages = [
          qsPkg
          toggle-shell
          qs-dev
          qs-test
          generate-theme
          custom-shell
          custom-shell-or
          lock-recover
          shell-stats
          wallpaper-thumbnails
          # qalc, for the launcher's calculator (launcher/CalculatorMode.qml).
          pkgs.libqalculate
        ]
        # GTK 3's theme, recoloured by gtk.css (generate-theme).
        ++ lib.optional themeApps pkgs.adw-gtk3;

        # A rebuild that changes the shell restarts it, if it is running. Hyprland runs
        # the restart, so the shell starts with the session's environment rather than
        # this activation's. Nothing happens while Hyprland is not running (as at
        # boot); the activation carries on whatever happens here.
        xdg.configFile."quickshell/custom-shell" = {
          source = shellConfig;
          onChange = ''
            (
              export PATH=/run/current-system/sw/bin:$PATH
              # Without a Hyprland, jq is handed something that is not JSON.
              {
                ${liveHyprland pkgs}
              } 2>/dev/null
              [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0
              echo "Restarting the custom shell, if it is running"
              hyprctl dispatch exec "${toggle-shell}/bin/toggle-shell restart" >/dev/null
            ) || true
          '';
        };

        # Clipboard history for the launcher's "cc" mode. wl-paste --watch hands every
        # copy to cliphist, which keeps the newest 500 and skips copies a password
        # manager marks secret (CLIPBOARD_STATE=sensitive). A user service, so it runs
        # under any shell.
        services.cliphist = {
          enable = true;
          allowImages = true;
          extraOptions = [
            "-max-items"
            "500"
          ];
        };

        # The shell's drawers are Hyprland global shortcuts, like Caelestia's panels:
        # each does nothing while this shell is not running. Hyprland runs every bind
        # that matches a key, so Super+D, N and Escape are shared with Caelestia and
        # ambxst.
        wayland.windowManager.hyprland.settings = {
          # Through toggle-shell, which keeps the pid file the rebuild restart and
          # lock-recover use.
          exec-once = lib.mkIf config.local.customShell.atLogin [ "toggle-shell custom" ];
          bindd = [
            "$mod, R, App launcher, exec, custom-shell-or launcher ${pkgs.fuzzel}/bin/fuzzel"
            "$mod, slash, Keybind cheatsheet, exec, custom-shell-or cheatsheet hypr-cheatsheet"
            # Caelestia and ambxst each lock on logind's Lock signal.
            "$mod, L, Lock the session, exec, custom-shell-or lock loginctl lock-session"
            "$mod, ESCAPE, Session menu (custom shell), global, custom-shell:session"
            "$mod, N, Notification history (custom shell), global, custom-shell:notifications"
            "$mod, D, Dashboard (custom shell), global, custom-shell:dashboard"
            "$mod, I, Shell settings (custom shell), global, custom-shell:settings"
          ];
          # The settings window is an ordinary window (quickshell/settings): float it,
          # centred, at the size it is drawn for.
          windowrule = [
            "float on, center on, size 960 700, match:class ^(org\\.quickshell)$, match:title ^(Shell settings)$"
          ];
          # The brightness keys still run brightnessctl (hyprland.nix); this also tells
          # the shell, which shows the new level. The backlight sends no change events.
          binddel = [
            ", XF86MonBrightnessUp, Show the brightness level (custom shell), global, custom-shell:brightness"
            ", XF86MonBrightnessDown, Show the brightness level (custom shell), global, custom-shell:brightness"
          ];
        };

        # Lock before the machine sleeps. On suspend logind asks the session to lock:
        # the custom shell locks through hypridle's lock_cmd, Caelestia and ambxst on
        # the signal itself. inhibit_sleep = 3 holds the sleep back (logind allows 5 s)
        # until Hyprland reports every screen locked. No idle timeouts: this desktop
        # never locks or sleeps by itself (hypridle logs "No rules configured" for that,
        # and carries on).
        #
        # The unit is NixOS's (programs.hyprlock turns hypridle on), and it does not
        # restart by itself when this file changes.
        xdg.configFile."hypr/hypridle.conf" = {
          text = ''
            general {
                lock_cmd = ${custom-shell-or}/bin/custom-shell-or lock true
                before_sleep_cmd = loginctl lock-session
                inhibit_sleep = 3
            }
          '';
          onChange = ''
            ${pkgs.systemd}/bin/systemctl --user reset-failed hypridle.service 2>/dev/null || true
            ${pkgs.systemd}/bin/systemctl --user restart hypridle.service 2>/dev/null || true
          '';
        };

        home.activation = {
          # First run, or the theme cache was cleared: choose the wallpaper (the saved
          # choice, else the first in ~/Pictures/Wallpapers, linked by then) and
          # generate the theme. With themeApps, also when GTK's gtk.css is not
          # generate-theme's: another shell wrote it (ambxst did before), or themeApps
          # has just been turned on, and home-manager's dconf step has just reset the
          # GTK keys it used to set. dconf needs a session bus: outside a session, a
          # private one, as that step uses.
          generateTheme = config.lib.dag.entryAfter [ "linkGeneration" "dconfSettings" ] ''
            regenerate=false
            [ -f "$HOME/.cache/qs-theme/colors.json" ] || regenerate=true
            [ -f "''${XDG_STATE_HOME:-$HOME/.local/state}/custom-shell/wallpaper.json" ] || regenerate=true
            ${lib.optionalString themeApps ''
              grep -qs generate-theme "${config.xdg.configHome}/gtk-3.0/gtk.css" || regenerate=true
            ''}
            if $regenerate; then
              if [ -v DBUS_SESSION_BUS_ADDRESS ]; then
                run ${generate-theme}/bin/generate-theme || true
              else
                run ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon \
                  ${generate-theme}/bin/generate-theme || true
              fi
            fi
          '';

          # The settings from Nix, beside the user's own settings.json, which the
          # settings window writes and so must not be a home-manager file. A copy rather
          # than a home-manager link: the shell's watch follows a link to its store
          # file, which never changes, so it misses a rebuild's new link; a file renamed
          # into place it sees. Read only, as edits belong in Nix.
          customShellSettings =
            let
              defaults =
                (pkgs.formats.json { }).generate "custom-shell-defaults.json"
                  config.local.customShell.settings;
            in
            config.lib.dag.entryAfter [ "writeBoundary" ] ''
              dir="${config.xdg.configHome}/custom-shell"
              run mkdir -p "$dir"
              if ! ${pkgs.diffutils}/bin/cmp -s ${defaults} "$dir/defaults.json"; then
                run install -m444 ${defaults} "$dir/.defaults.json.new"
                run mv -f "$dir/.defaults.json.new" "$dir/defaults.json"
              fi
            '';
        };
      };
    };
}
