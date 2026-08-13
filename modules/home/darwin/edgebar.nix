# Renders edgebar's runtime config (~/.config/edgebar/config.json) so the one
# value that must stay in sync with AeroSpace's window gaps — the bar height —
# is single-sourced in Nix (flake.lib.barGeometry, see bar-geometry.nix) and
# shared with aerospace.nix's outer.top.
#
# Colors/role-maps + geometry stay editable in the committed source of truth,
# apps/edgebar/src-tauri/config.default.json (also the binary's bundled
# fallback); we import that and override only geometry.barHeight, so editing it
# there + rebuild is all that's needed. edgebar reads this file at startup,
# falling back to the bundled default when it's absent.
#
# The wallpaper-derived PALETTE is separate: `generate-edgebar-theme` runs
# matugen (edgebar/matugen) over the current wallpaper to write
# ~/.config/edgebar/palette.json (light + dark), then pings edgebar's theme.sock
# so the running bar re-themes live. edgebar falls back to the bundled
# palette.default.json (Catppuccin Latte/Mocha) when that file is absent.
{ config, lib, ... }:
let
  geom = config.flake.lib.barGeometry;
  wp = config.flake.lib.wallpaper;
  defaults = lib.importJSON ../../../apps/edgebar/src-tauri/config.default.json;
  rendered = defaults // {
    geometry = defaults.geometry // {
      barHeight = geom.barHeight;
      # fillet radius is locked to half the pill height
      concave = defaults.geometry.pillHeight / 2;
    };
  };
  matugenDir = ./edgebar/matugen;
in
{
  flake.modules.homeManager.darwin-edgebar =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      defaultWallpaper = "$HOME/${wp.dir}/${wp.default}";
      generate-edgebar-theme = pkgs.writeShellScriptBin "generate-edgebar-theme" ''
        CONFIG_DIR="${matugenDir}"
        # Scheme: explicit --scheme arg > the persisted choice (select-scheme) >
        # the matugen default.
        SCHEME="$(cat "$HOME/.config/edgebar/scheme" 2>/dev/null || echo scheme-tonal-spot)"
        WALLPAPER=""
        OUT="$HOME/.config/edgebar/palette.json"
        PING=1
        EXPLICIT_WALL=0

        # generate-edgebar-theme [wallpaper] [--scheme X] [--out FILE]
        #   --out FILE  render the palette to FILE and skip the socket ping — used
        #               by edgebar to precompute per-wallpaper palette caches.
        while [ $# -gt 0 ]; do
          case "$1" in
            --scheme) SCHEME="$2"; shift 2 ;;
            --out) OUT="$2"; PING=0; shift 2 ;;
            *) WALLPAPER="$1"; EXPLICIT_WALL=1; shift ;;
          esac
        done

        # Skip the launchd watcher's redundant run right after an in-app change:
        # edgebar already themed it instantly, and re-running could clobber a newer
        # pick. Only the no-arg (watcher) live invocation honours the marker.
        MARKER="$HOME/.cache/edgebar/.inapp-change"
        if [ "$EXPLICIT_WALL" = 0 ] && [ "$PING" = 1 ] && [ -f "$MARKER" ]; then
          AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || echo 0) ))
          [ "$AGE" -lt 3 ] && exit 0
        fi

        # Resolve the wallpaper: explicit arg > current desktop (desktoppr) > default.
        if [ -z "$WALLPAPER" ]; then
          WALLPAPER=$(${pkgs.desktoppr}/bin/desktoppr 2>/dev/null | head -1)
        fi
        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
          WALLPAPER="${defaultWallpaper}"
        fi
        if [ ! -f "$WALLPAPER" ]; then
          echo "generate-edgebar-theme: no wallpaper found ($WALLPAPER)" >&2
          exit 1
        fi

        echo "edgebar theme ← $WALLPAPER (scheme: $SCHEME) → $OUT"

        TMP="$(mktemp -d)"
        # matugen extracts colours from a 512px downscale (~4x faster than 4K,
        # colour-equivalent).
        SRC="$WALLPAPER"
        if /usr/bin/sips -Z 512 -s format png "$WALLPAPER" --out "$TMP/src.png" >/dev/null 2>&1; then
          SRC="$TMP/src.png"
        fi

        # Render to a staging file in OUT's directory, then atomically rename — so
        # edgebar never reads a half-written palette and concurrent runs can't
        # interleave.
        mkdir -p "$(dirname "$OUT")"
        STAGE="$OUT.staging.$$"
        printf '[config]\n[templates.edgebar]\ninput_path = "%s/palette.json.tmpl"\noutput_path = "%s"\n' \
          "$CONFIG_DIR" "$STAGE" > "$TMP/cfg.toml"

        if ! ${pkgs.matugen}/bin/matugen image "$SRC" \
          --source-color-index 0 \
          -c "$TMP/cfg.toml" \
          -t "$SCHEME"; then
          echo "matugen failed — palette not regenerated" >&2
          rm -rf "$TMP"; rm -f "$STAGE"
          exit 1
        fi
        mv -f "$STAGE" "$OUT"
        rm -rf "$TMP"

        if [ "$PING" = 1 ]; then
          nc -U "$HOME/.cache/edgebar/theme.sock" </dev/null 2>/dev/null || true
        fi
      '';

      # Wallpaper commands. They only SET the desktop picture; the launchd watcher
      # below re-themes edgebar from whatever the wallpaper becomes, so the theme
      # follows the wallpaper however it was changed.
      cycle-wallpaper = pkgs.writeShellApplication {
        name = "cycle-wallpaper";
        runtimeInputs = [
          pkgs.desktoppr
          generate-edgebar-theme
        ];
        text = builtins.readFile ./edgebar/cycle-wallpaper.sh;
      };
      select-wallpaper = pkgs.writeShellApplication {
        name = "select-wallpaper";
        runtimeInputs = [
          pkgs.desktoppr
          generate-edgebar-theme
        ];
        text = builtins.readFile ./edgebar/select-wallpaper.sh;
      };
      # Picks the matugen scheme type and re-themes the current wallpaper.
      select-scheme = pkgs.writeShellApplication {
        name = "select-scheme";
        runtimeInputs = [ generate-edgebar-theme ];
        text = builtins.readFile ./edgebar/select-scheme.sh;
      };
      # Seeds the persisted scheme choice for this machine. Same
      # stamp-on-change rule as the wallpaper: writes ~/.config/edgebar/scheme
      # only when the DECLARED scheme differs from the one last applied, so a
      # later `select-scheme` pick survives every unchanged rebuild.
      seed-scheme = pkgs.writeShellScript "seed-edgebar-scheme" ''
        stamp="$HOME/.local/state/edgebar/scheme-default"
        want="${config.local.edgebar.scheme}"
        [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && exit 0

        mkdir -p "$HOME/.config/edgebar" "$(dirname "$stamp")"
        printf '%s\n' "$want" > "$HOME/.config/edgebar/scheme"
        printf '%s' "$want" > "$stamp"

        # A scheme change repaints the palette immediately — the file alone
        # would leave a stale palette.json until the next wallpaper change.
        ${generate-edgebar-theme}/bin/generate-edgebar-theme || true
      '';
    in
    {
      options.local.edgebar.scheme = lib.mkOption {
        type = lib.types.str;
        default = "scheme-tonal-spot";
        example = "scheme-expressive";
        description = ''
          matugen scheme this machine derives its edgebar palette with — see
          the list in edgebar/select-scheme.sh. Written to
          ~/.config/edgebar/scheme on the first activation that declares it,
          and again whenever this value changes, never on an unchanged
          rebuild.
        '';
      };

      config = {
        # Inject the binaries the in-app theme view shells out to (absolute
        # store paths so they resolve regardless of the bar's launch
        # environment).
        xdg.configFile."edgebar/config.json".text = builtins.toJSON (
          rendered
          // {
            themeCommand = "${generate-edgebar-theme}/bin/generate-edgebar-theme";
            wallpaperCommand = "${pkgs.desktoppr}/bin/desktoppr";
          }
        );

        home.packages = [
          generate-edgebar-theme
          cycle-wallpaper
          select-wallpaper
          select-scheme
        ];

        # Scheme first, so the palette below is generated with it. Runs before
        # the wallpaper seed's own re-theme too — both are idempotent.
        home.activation.edgebarScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${seed-scheme}
        '';

        # Seed palette.json from the wallpaper on first build (later wallpaper
        # changes are driven by running generate-edgebar-theme). Absent the
        # file, edgebar uses the bundled Catppuccin fallback, so a matugen
        # failure here is non-fatal.
        home.activation.edgebarTheme = lib.hm.dag.entryAfter [ "edgebarScheme" ] ''
          if [ ! -f "$HOME/.config/edgebar/palette.json" ]; then
            run ${generate-edgebar-theme}/bin/generate-edgebar-theme || true
          fi
        '';

        # Catch wallpaper changes made OUTSIDE edgebar (System Settings, other
        # tools) — edgebar's own commands re-theme directly and instantly.
        # macOS rewrites this plist whenever the desktop picture changes
        # (verified: desktoppr and System Settings both touch it); launchd
        # WatchPaths fires generate-edgebar-theme, which reads the now-current
        # wallpaper and pings the bar. Event-driven, no polling.
        # ThrottleInterval=1 trims launchd's default 10s minimum respawn so
        # external changes still follow within ~1s.
        launchd.agents.edgebar-wallpaper-theme = {
          enable = true;
          config = {
            ProgramArguments = [ "${generate-edgebar-theme}/bin/generate-edgebar-theme" ];
            WatchPaths = [
              "${config.home.homeDirectory}/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
            ];
            RunAtLoad = false;
            ThrottleInterval = 1;
            ProcessType = "Background";
            StandardOutPath = "/tmp/edgebar-wallpaper-theme.log";
            StandardErrorPath = "/tmp/edgebar-wallpaper-theme.log";
          };
        };
      };
    };
}
