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
      # here and by qs-dev. A shader that does not compile fails the build.
      compileShaders = dir: ''
        for shader in "${dir}"/shaders/*.frag "${dir}"/shaders/*.vert; do
          [ -e "$shader" ] || continue
          ${pkgs.qt6.qtshadertools}/bin/qsb --qt6 -o "$shader.qsb" "$shader" || exit 1
        done
      '';

      # Quickshell only knows hicolor unless told the icon theme; use the GTK one, so
      # the launcher's icons match every other app's.
      iconThemeEnv = lib.optionalString (
        config.gtk.iconTheme != null
      ) "export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}";

      # MangoHud is on for the whole session (profile-gaming), and its Vulkan layer
      # loads into the shell too, where its NVIDIA thread kept about 28% of a core busy.
      noMangoHud = "export DISABLE_MANGOHUD=1";

      # `custom-shell-or <shortcut> <fallback...>` fires one of the custom shell's global
      # shortcuts (a drawer, or the lock) while that shell has it registered, and runs
      # the fallback under the other shells. It keeps Super+R, Super+/ and Super+L
      # working everywhere until the custom shell is the session's shell (custom-shell
      # issue 22).
      custom-shell-or = pkgs.writeShellScriptBin "custom-shell-or" ''
        drawer=$1
        shift
        if hyprctl globalshortcuts -j | ${pkgs.jq}/bin/jq -e --arg name "custom-shell:$drawer" 'any(.[]; .name == $name)' >/dev/null; then
          exec hyprctl dispatch global "custom-shell:$drawer"
        fi
        exec "$@"
      '';

      # From a text console (Ctrl+Alt+F2, log in), when the lock screen has died or will
      # not take the password: starts the custom shell again and, once you are back on
      # Hyprland's VT, has it lock, so the password unlocks (docs/lock-screen.md).
      # Hyprland lets a new lock take over only while misc:allow_session_lock_restore is
      # on, which would let any program replace a working lock too, so it is on just for
      # these few seconds.
      lock-recover = pkgs.writeShellScriptBin "lock-recover" ''
        set -u
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
          ]
        }:$PATH
        hypr() { hyprctl --instance 0 "$@"; }
        if ! hypr version >/dev/null 2>&1; then
          echo "Hyprland is not running" >&2
          exit 1
        fi

        pidfile=/tmp/custom-shell.pid
        if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
          echo "Stopping the custom shell..."
          pid=$(cat "$pidfile")
          kill "$pid"
          for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
          kill -9 "$pid" 2>/dev/null
          rm -f "$pidfile"
        fi

        echo "Starting the custom shell..."
        hypr dispatch exec toggle-shell custom >/dev/null
        started=false
        for _ in $(seq 50); do
          if hypr globalshortcuts -j | jq -e 'any(.[]; .name == "custom-shell:lock")' >/dev/null; then
            started=true
            break
          fi
          sleep 0.2
        done
        last_resort() {
          echo "Last resort, which ends the session and loses unsaved work:" >&2
          echo "  hyprctl --instance 0 dispatch exit" >&2
        }
        if ! $started; then
          echo "The custom shell did not start within 10 s, so nothing could lock." >&2
          last_resort
          exit 1
        fi

        # A lock asked for while Hyprland's VT is in the background breaks: the shell
        # died with a Wayland protocol error both times it was tried from here, and
        # locked once Hyprland's VT was showing (2026-10-10). So lock only once you are
        # back there. Hyprland's VT is its logind session's.
        hpid=$(hyprctl instances -j | jq -r 'sort_by(-.time) | .[0].pid')
        vt=$(loginctl show-session "$(cat "/proc/$hpid/sessionid")" -p VTNr --value 2>/dev/null)
        vt=''${vt:-1}
        echo "Now press Ctrl+Alt+F$vt: the lock screen appears there a few seconds later."
        for _ in $(seq 300); do
          [ "$(cat /sys/class/tty/tty0/active)" = "tty$vt" ] && break
          sleep 1
        done
        if [ "$(cat /sys/class/tty/tty0/active)" != "tty$vt" ]; then
          echo "tty$vt was not showing within 5 minutes; run lock-recover again." >&2
          exit 1
        fi
        # Hyprland sets its monitors up again as its VT comes back.
        sleep 2

        hypr keyword misc:allow_session_lock_restore 1 >/dev/null
        hypr dispatch global custom-shell:lock >/dev/null
        sleep 2
        hypr keyword misc:allow_session_lock_restore 0 >/dev/null

        # You are on tty$vt by now: this is for when you come back here.
        sleep 2
        if kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
          echo "Locked by the custom shell. Once unlocked, log out here with exit."
        else
          echo "The custom shell died while locking; its output is in" >&2
          echo "''${XDG_RUNTIME_DIR:-/tmp}/custom-shell.log. Run lock-recover again." >&2
          last_resort
          exit 1
        fi
      '';

      # Statistics for the dashboard's performance tab: a JSON line a second while the
      # tab shows (shell-stats/src/main.rs).
      shell-stats = pkgs.rustPlatform.buildRustPackage {
        pname = "shell-stats";
        version = "0.1.0";
        src = ./shell-stats;
        cargoLock.lockFile = ./shell-stats/Cargo.lock;
        meta.mainProgram = "shell-stats";
      };

      # Thumbnails for the wallpaper picker, made once per image: ~/Pictures/Wallpapers/<name>
      # becomes ~/.cache/custom-shell/wallpaper-thumbnails/<name>.<size in bytes>.jpg, so
      # an image replaced under the same name gets a new one. Written under a temporary
      # name and moved into place, so the picker never shows half a file.
      wallpaper-thumbnails = pkgs.writeShellScriptBin "wallpaper-thumbnails" ''
        SRC="''${1:-$HOME/Pictures/Wallpapers}"
        OUT="''${XDG_CACHE_HOME:-$HOME/.cache}/custom-shell/wallpaper-thumbnails"
        mkdir -p "$OUT"
        # The picker starts watching the folder on this line, so it must exist first.
        echo ready
        for f in "$SRC"/*; do
          [ -f "$f" ] || continue
          case "''${f,,}" in
            *.jpg | *.jpeg | *.png | *.webp) ;;
            *) continue ;;
          esac
          thumb="$OUT/$(basename "$f").$(stat -L -c %s "$f").jpg"
          [ -e "$thumb" ] && continue
          # The temporary name must not end in .jpg: the picker only sees a thumbnail
          # arrive when the number of .jpg files changes, which a rename does not do.
          ${pkgs.imagemagick}/bin/magick "$f[0]" -auto-orient -thumbnail '384x216^' \
            -gravity center -extent 384x216 -quality 85 "jpg:$thumb.part" \
            && mv "$thumb.part" "$thumb"
        done
      '';

      shellConfig = pkgs.runCommand "custom-shell-config" { } ''
        cp -r ${./quickshell} $out
        chmod -R u+w $out
        ${compileShaders "$out"}
      '';

      toggle-shell = pkgs.writeShellScriptBin "toggle-shell" ''
        CUSTOM_PID_FILE="/tmp/custom-shell.pid"
        # A shell started from a terminal that outlived a Hyprland restart cannot reach
        # Hyprland's socket, so it does not know which monitor is focused and no drawer
        # opens.
        ${liveHyprland pkgs}

        AMBXST_PATTERN="quickshell.*ambxst-shell"
        # The qs process runs with `-p <store>/share/caelestia-shell`.
        CAELESTIA_PATTERN="share/caelestia-shell"

        ambxst_running() {
          pgrep -f "$AMBXST_PATTERN" >/dev/null 2>&1
        }

        custom_running() {
          [ -f "$CUSTOM_PID_FILE" ] && kill -0 "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
        }

        caelestia_running() {
          pgrep -f "$CAELESTIA_PATTERN" >/dev/null 2>&1
        }

        stop_ambxst() {
          if ambxst_running; then
            echo "Stopping ambxst..."
            pkill -f "$AMBXST_PATTERN" 2>/dev/null
            sleep 0.5
          fi
        }

        stop_custom() {
          if custom_running; then
            echo "Stopping custom shell..."
            kill "$(cat "$CUSTOM_PID_FILE")" 2>/dev/null
            rm -f "$CUSTOM_PID_FILE"
            sleep 0.5
          fi
        }

        stop_caelestia() {
          if caelestia_running; then
            echo "Stopping Caelestia..."
            caelestia shell -k >/dev/null 2>&1 || pkill -f "$CAELESTIA_PATTERN" 2>/dev/null
            sleep 0.5
          fi
        }

        case "''${1:-}" in
          status)
            echo "ambxst:       $(ambxst_running && echo "running (pid $(pgrep -f "$AMBXST_PATTERN" | head -1))" || echo "stopped")"
            echo "custom-shell: $(custom_running && echo "running (pid $(cat "$CUSTOM_PID_FILE"))" || echo "stopped")"
            echo "caelestia:    $(caelestia_running && echo "running (pid $(pgrep -f "$CAELESTIA_PATTERN" | head -1))" || echo "stopped")"
            ;;
          custom)
            if custom_running; then
              echo "Custom shell already running"
              exit 0
            fi
            stop_ambxst
            stop_caelestia
            echo "Starting custom shell..."
            export QSG_RHI_BACKEND=vulkan
            ${iconThemeEnv}
            ${noMangoHud}
            # Quickshell's own log misses the last words of a shell killed by a Wayland
            # protocol error (Qt exits at once); its output keeps them.
            ${qsPkg}/bin/qs -p "$HOME/.config/quickshell/custom-shell" \
              >"''${XDG_RUNTIME_DIR:-/tmp}/custom-shell.log" 2>&1 &
            echo $! > "$CUSTOM_PID_FILE"
            echo "Custom shell started (pid $!)"
            # mako starts on demand whenever nothing owns the notification service, so it
            # may hold it now. The shell takes the service as soon as mako lets go.
            systemctl --user stop mako.service 2>/dev/null || true
            ;;
          ambxst)
            if ambxst_running; then
              echo "ambxst already running"
              exit 0
            fi
            stop_custom
            stop_caelestia
            echo "Starting ambxst..."
            ambxst >/dev/null 2>&1 &
            echo "ambxst restarted"
            ;;
          caelestia)
            if ! command -v caelestia >/dev/null 2>&1; then
              echo "Caelestia is not installed on this host (desktop-caelestia)" >&2
              exit 1
            fi
            if caelestia_running; then
              echo "Caelestia already running"
              exit 0
            fi
            stop_ambxst
            stop_custom
            # ambxst binds its keys at runtime; a reload drops them so they
            # cannot fire alongside Caelestia's.
            hyprctl reload >/dev/null
            echo "Starting Caelestia..."
            caelestia shell -d >/dev/null 2>&1
            echo "Caelestia started"
            ;;
          *)
            echo "Usage: toggle-shell {custom|ambxst|caelestia|status}"
            echo ""
            echo "  custom     - Stop the other shells, start custom shell"
            echo "  ambxst     - Stop the other shells, restart ambxst"
            echo "  caelestia  - Stop the other shells, start Caelestia"
            echo "  status     - Show which shell is running"
            exit 1
            ;;
        esac
      '';

      matugenDir = ./quickshell/matugen;

      # Sets the wallpaper and generates the shell's theme from it with matugen:
      #   generate-theme [image] [--scheme X] [--mode light|dark | --light | --dark]
      # Anything not given comes from the saved choice; with no saved image, the first
      # in ~/Pictures/Wallpapers. The choice is kept in
      # ~/.local/state/custom-shell/wallpaper.json, which the shell watches to show the
      # image; the colours go to ~/.cache/qs-theme/colors.json. Paths are kept as given,
      # so a ~/Pictures/Wallpapers link stays valid across rebuilds where the store path
      # behind it would not.
      generate-theme = pkgs.writeShellScriptBin "generate-theme" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.findutils
            pkgs.jq
            pkgs.matugen
          ]
        }:$PATH
        STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/custom-shell"
        STATE="$STATE_DIR/wallpaper.json"
        # Where the choice lived before, as a store path that a rebuild leaves stale.
        OLD_STATE="$HOME/.cache/qs-theme/wallpaper.json"
        WALLPAPERS="$HOME/Pictures/Wallpapers"
        mkdir -p "$STATE_DIR" "$HOME/.cache/qs-theme"

        WALLPAPER=""
        SCHEME=""
        MODE=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --scheme) SCHEME="$2"; shift 2 ;;
            --mode) MODE="$2"; shift 2 ;;
            --dark) MODE="dark"; shift ;;
            --light) MODE="light"; shift ;;
            -h|--help)
              echo "Usage: generate-theme [image] [--scheme X] [--mode light|dark]"
              echo "Schemes: scheme-neutral, scheme-tonal-spot, scheme-content, scheme-fidelity,"
              echo "         scheme-expressive, scheme-fruit-salad, scheme-monochrome, scheme-rainbow"
              exit 0 ;;
            *) WALLPAPER="$1"; shift ;;
          esac
        done

        if [ -f "$STATE" ]; then
          [ -z "$WALLPAPER" ] && WALLPAPER=$(jq -r '.path // empty' "$STATE")
          [ -z "$SCHEME" ] && SCHEME=$(jq -r '.scheme // empty' "$STATE")
          [ -z "$MODE" ] && MODE=$(jq -r '.mode // empty' "$STATE")
        elif [ -f "$OLD_STATE" ]; then
          [ -z "$SCHEME" ] && SCHEME=$(jq -r '.scheme // empty' "$OLD_STATE")
          [ -z "$MODE" ] && MODE=$(jq -r '.mode // empty' "$OLD_STATE")
          if [ -z "$WALLPAPER" ]; then
            NAME=$(basename "$(jq -r '.currentWall // empty' "$OLD_STATE")")
            [ -n "$NAME" ] && [ -e "$WALLPAPERS/$NAME" ] && WALLPAPER="$WALLPAPERS/$NAME"
          fi
        fi
        if [ -z "$WALLPAPER" ] || [ ! -e "$WALLPAPER" ]; then
          WALLPAPER=$(find -L "$WALLPAPERS" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1)
        fi
        if [ -z "$WALLPAPER" ]; then
          echo "No wallpaper: give an image, or put some in $WALLPAPERS" >&2
          exit 1
        fi
        case "$WALLPAPER" in
          /*) ;;
          *) WALLPAPER="$PWD/$WALLPAPER" ;;
        esac
        SCHEME="''${SCHEME:-scheme-neutral}"
        MODE="''${MODE:-light}"

        # The choice first, so the shell starts loading the image while matugen runs.
        jq -n --arg path "$WALLPAPER" --arg scheme "$SCHEME" --arg mode "$MODE" \
          '{path: $path, scheme: $scheme, mode: $mode}' > "$STATE.tmp"
        mv "$STATE.tmp" "$STATE"

        echo "Generating theme: $WALLPAPER (scheme: $SCHEME, mode: $MODE)"
        if ! matugen image "$WALLPAPER" \
          --source-color-index 0 \
          -c "${matugenDir}/config.toml" \
          -t "$SCHEME" \
          -m "$MODE"; then
          echo "matugen failed — theme not generated" >&2
          exit 1
        fi
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
        export QSG_RHI_BACKEND=vulkan
        ${iconThemeEnv}
        ${noMangoHud}
        exec ${qsPkg}/bin/qs -p "$SHELL_DIR"
      '';
    in
    {
      home.packages = [
        qsPkg
        toggle-shell
        qs-dev
        generate-theme
        custom-shell-or
        lock-recover
        shell-stats
        wallpaper-thumbnails
      ];

      xdg.configFile."quickshell/custom-shell".source = shellConfig;

      # Clipboard history for the launcher's "cc" mode. wl-paste --watch hands every
      # copy to cliphist, which keeps the newest 500 and skips copies a password manager
      # marks secret (CLIPBOARD_STATE=sensitive). A user service, so it runs under any
      # shell.
      services.cliphist = {
        enable = true;
        allowImages = true;
        extraOptions = [
          "-max-items"
          "500"
        ];
      };

      # The shell's drawers are Hyprland global shortcuts, like Caelestia's panels: each
      # does nothing while this shell is not running. Hyprland runs every bind that
      # matches a key, so Super+D, N and Escape are shared with Caelestia and ambxst.
      wayland.windowManager.hyprland.settings = {
        bindd = [
          "$mod, R, App launcher, exec, custom-shell-or launcher ${pkgs.fuzzel}/bin/fuzzel"
          "$mod, slash, Keybind cheatsheet, exec, custom-shell-or cheatsheet hypr-cheatsheet"
          # Caelestia and ambxst each lock on logind's Lock signal.
          "$mod, L, Lock the session, exec, custom-shell-or lock loginctl lock-session"
          "$mod, ESCAPE, Session menu (custom shell), global, custom-shell:session"
          "$mod, N, Notification history (custom shell), global, custom-shell:notifications"
          "$mod, D, Dashboard (custom shell), global, custom-shell:dashboard"
        ];
        # The brightness keys still run brightnessctl (hyprland.nix); this also tells
        # the shell, which shows the new level. The backlight sends no change events.
        binddel = [
          ", XF86MonBrightnessUp, Show the brightness level (custom shell), global, custom-shell:brightness"
          ", XF86MonBrightnessDown, Show the brightness level (custom shell), global, custom-shell:brightness"
        ];
      };

      # Lock before the machine sleeps. On suspend logind asks the session to lock: the
      # custom shell locks through hypridle's lock_cmd, Caelestia and ambxst on the signal
      # itself. inhibit_sleep = 3 holds the sleep back (logind allows 5 s) until Hyprland
      # reports every screen locked. No idle timeouts: this desktop never locks or sleeps
      # by itself (hypridle logs "No rules configured" for that, and carries on).
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

      # First run, or the theme cache was cleared: choose the wallpaper (the saved choice,
      # else the first in ~/Pictures/Wallpapers, linked by then) and generate the theme.
      home.activation.generateTheme = config.lib.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -f "$HOME/.cache/qs-theme/colors.json" ] \
          || [ ! -f "''${XDG_STATE_HOME:-$HOME/.local/state}/custom-shell/wallpaper.json" ]; then
          run ${generate-theme}/bin/generate-theme || true
        fi
      '';
    };
}
