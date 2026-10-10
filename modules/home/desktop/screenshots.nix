# Screenshots on Print, split the way macOS splits them, under any shell: plain Print
# opens a region in swappy to mark up and save (Cmd+Shift+4), Ctrl copies the region
# (Ctrl+Cmd+Shift+4), Shift takes the whole focused monitor (Cmd+Shift+3) to the
# clipboard, with Open and Save in its notification. macOS's own keys are taken here:
# Super+Shift+3/4 move windows between workspaces.
#
# The region picker (grimblast's `area`, through slurp) freezes the screen first, so it
# captures what was there when the key went down, and clicking a window selects the
# whole window. grimblast's freeze is hyprpicker's.
_: {
  flake.modules.homeManager.desktop-screenshots =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      saveDir = "${config.xdg.userDirs.pictures}/Screenshots";

      screenshot = pkgs.writeShellScriptBin "screenshot" ''
        set -eu
        export PATH=${
          lib.makeBinPath [
            pkgs.grimblast
            pkgs.swappy
            pkgs.wl-clipboard
            pkgs.libnotify
            pkgs.coreutils
          ]
        }:$PATH
        export GRIMBLAST_EDITOR="swappy -f"
        # grimblast hands the editor a file in /tmp, readable by everyone, and leaves it;
        # the runtime directory is private and goes at logout.
        export DEFAULT_TMP_EDITOR_DIR="''${XDG_RUNTIME_DIR:-/tmp}"

        case "''${1:-}" in
          region) exec grimblast --freeze edit area ;;
          region-copy) exec grimblast --freeze copy area ;;
          monitor)
            file=$(mktemp --suffix=.png "''${XDG_RUNTIME_DIR:-/tmp}/screenshot-XXXXXX")
            trap 'rm -f "$file"' EXIT
            grimblast save output "$file" >/dev/null
            wl-copy --type image/png < "$file"
            # notify-send waits here until an action is chosen or the notification closes.
            # The custom shell keeps an expired notification in its history, buttons and
            # all, so give up after ten minutes rather than wait for ever.
            action=$(timeout 600 notify-send -a Screenshot -h "string:image-path:$file" \
              -A open=Open -A save=Save \
              "Screenshot copied" "The monitor is on the clipboard.") || true
            case "$action" in
              open) swappy -f "$file" ;;
              save)
                mkdir -p "${saveDir}"
                saved="${saveDir}/Screenshot_$(date +%Y%m%d_%H%M%S).png"
                cp "$file" "$saved"
                notify-send -a Screenshot "Screenshot saved" "$saved"
                ;;
            esac
            ;;
          *)
            echo "Usage: screenshot {region|region-copy|monitor}" >&2
            exit 2
            ;;
        esac
      '';
    in
    {
      home.packages = [ screenshot ];

      # swappy saves to ~/Desktop, else $HOME, and there is no ~/Desktop
      # (desktop-hyprland); save to Pictures/Screenshots, beside the monitor shots.
      # The screenshot script carries swappy on its own PATH, so only the config here.
      programs.swappy = {
        enable = true;
        package = null;
        settings.Default.save_dir = saveDir;
      };

      wayland.windowManager.hyprland.settings.bindd = [
        ", Print, Screenshot a region (swappy), exec, screenshot region"
        "CTRL, Print, Screenshot a region to the clipboard, exec, screenshot region-copy"
        "SHIFT, Print, Screenshot the monitor to the clipboard, exec, screenshot monitor"
      ];
    };
}
