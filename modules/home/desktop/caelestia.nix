# Caelestia shell (github:caelestia-dots/shell) in the Crimson Ronin palette
# (github:corund207/crimson-ronin, MIT): about 80% black/graphite, with
# crimson kept to edges and status. A host that imports this module starts
# Caelestia as its session shell, in place of desktop-ambxst. ambxst stays
# installed (programs.ambxst in system/nixos/hyprland.nix), so
# `toggle-shell ambxst` swaps it in and `toggle-shell caelestia` swaps back.
{ inputs, ... }:
let
  ronin = inputs.crimson-ronin;
in
{
  flake.modules.homeManager.desktop-caelestia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;

      roninScheme = lib.importJSON "${ronin}/state/caelestia/scheme.json";

      # Crimson Ronin ships its palette as a "dynamic" scheme, and the CLI
      # regenerates a dynamic scheme from the image on every wallpaper change
      # (set_wallpaper → update_colours in utils/wallpaper.py), so the first
      # wallpaper pick would throw the hand-tuned colours away. As a static
      # scheme they survive. The CLI only reads static schemes from inside its
      # own package — there is no user directory for them — hence the override.
      schemeFile = pkgs.writeText "crimsonronin-dark.txt" (
        lib.concatLines (lib.mapAttrsToList (name: hex: "${name} ${hex}") roninScheme.colours)
      );
      cli = inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.default.overrideAttrs (old: {
        # Upstream's postInstall has no trailing newline, hence the "\n".
        postInstall =
          (old.postInstall or "")
          + "\n"
          + ''
            install -Dm644 ${schemeFile} \
              $out/${pkgs.python3.sitePackages}/caelestia/data/schemes/crimsonronin/default/dark.txt
          '';
      });
      # The shell calls the CLI to change scheme and wallpaper, so it has to
      # carry the same override.
      shell = inputs.caelestia-shell.packages.${system}.caelestia-shell.override {
        withCli = true;
        caelestia-cli = cli;
      };

      seedScheme = pkgs.writeText "caelestia-scheme.json" (
        builtins.toJSON {
          name = "crimsonronin";
          flavour = "default";
          mode = "dark";
          inherit (roninScheme) variant colours;
        }
      );
      wallpaper = "${ronin}/assets/crimson-ronin-4k.png";

      roninGtk = pkgs.runCommand "crimson-ronin-gtk-theme" { } ''
        mkdir -p $out/share/themes
        cp -r ${ronin}/themes/gtk/CrimsonRonin $out/share/themes/
      '';
    in
    {
      imports = [ inputs.caelestia-shell.homeManagerModules.default ];

      programs.caelestia = {
        enable = true;
        package = shell;
        # Hyprland's exec-once starts it (below), with the command that
        # toggle-shell uses, so both start it outside systemd.
        systemd.enable = false;

        # Crimson Ronin's config/caelestia/shell.json, with this machine's
        # terminal and without its Arch paths.
        settings = {
          general = {
            logo = "${ronin}/assets/ronin-mark.svg";
            showOverFullscreen = false;
            apps.terminal = [ "kitty" ];
            # Upstream locks at 3 min, turns the screens off at 5 and
            # suspend-then-hibernates at 10. Hibernate cannot work here (zram
            # only, no swap partition) and a gaming desktop should not
            # suspend by itself, so the trial leaves power behaviour alone.
            idle.timeouts = [ ];
          };
          appearance = {
            deformScale = 0.76;
            anim.durations.scale = 0.68;
            rounding.scale = 0.88;
            spacing.scale = 0.86;
            padding.scale = 0.88;
            transparency = {
              enabled = true;
              base = 0.74;
              layers = 0.20;
            };
          };
          border = {
            thickness = 1;
            rounding = 16;
            smoothing = 1;
          };
          bar = {
            persistent = true;
            showOnHover = false;
            workspaces = {
              shown = 10;
              activeIndicator = true;
              occupiedBg = false;
              showWindows = false;
              maxWindowIcons = 0;
              activeTrail = false;
            };
            tray = {
              background = false;
              compact = true;
            };
            clock.background = false;
          };
          launcher = {
            enabled = true;
            showOnHover = false;
            maxShown = 7;
            enableDangerousActions = false;
            vimKeybinds = true;
          };
          dashboard = {
            enabled = true;
            showOnHover = false;
            showDashboard = true;
            showMedia = false;
            showPerformance = true;
            showWeather = false;
            resourceUpdateInterval = 2000;
          };
          notifs = {
            expire = true;
            defaultExpireTimeout = 5000;
            fullscreenExpireTimeout = 1800;
            groupPreviewNum = 2;
            openExpanded = false;
          };
          # The session menu's and lock screen's power buttons. Caelestia's
          # defaults call logind directly; session-exit (from
          # desktop-session-restore) saves the open apps for the next login,
          # then has hyprshutdown close them before Hyprland exits. Caelestia
          # runs a command it does not recognise as a plain process.
          session.commands = {
            logout = [
              "session-exit"
              "logout"
            ];
            shutdown = [
              "session-exit"
              "poweroff"
            ];
            reboot = [
              "session-exit"
              "reboot"
            ];
          };
        };

        cli = {
          enable = true;
          package = cli;
          # Each of these defaults to on (`check` in utils/theme.py), and each
          # rewrites that app's config on every scheme or wallpaper change —
          # GTK and Qt included, which home-manager also writes. Off for the
          # trial, so only the shell itself takes the palette.
          settings.theme = lib.genAttrs [
            "enableTerm"
            "enableHypr"
            "enableDiscord"
            "enableSpicetify"
            "enablePandora"
            "enableFuzzel"
            "enableBtop"
            "enableNvtop"
            "enableHtop"
            "enableGtk"
            "enableQt"
            "enableWarp"
            "enableChromium"
            "enableZed"
            "enableCava"
          ] (_: false);
        };
      };

      # Caelestia's region picker and the Open button on a full-screen shot
      # both open swappy. The shell's and the CLI's wrappers carry swappy on
      # their own PATH, so only its config is needed here. Swappy saves to
      # ~/Desktop, else $HOME, and there is no ~/Desktop (desktop-hyprland).
      # Pictures/Screenshots is where Caelestia's Save puts full-screen
      # shots; swappy creates it if it is missing.
      programs.swappy = {
        enable = true;
        package = null;
        settings.Default.save_dir = "${config.xdg.userDirs.pictures}/Screenshots";
      };

      # In the wallpaper picker next to desktop-wallpapers' images.
      home.file."Pictures/Wallpapers/crimson-ronin-4k.png".source = wallpaper;

      # Seed the scheme and wallpaper once and never overwrite them: both can
      # be changed from inside the shell, and a rebuild must not undo that.
      # `caelestia scheme set -n crimsonronin` restores the palette.
      home.activation.caelestiaState = config.lib.dag.entryAfter [ "linkGeneration" ] ''
        state="${config.xdg.stateHome}/caelestia"
        if [ ! -f "$state/scheme.json" ]; then
          mkdir -p "$state"
          install -m644 ${seedScheme} "$state/scheme.json"
        fi
        if [ ! -f "$state/wallpaper/path.txt" ]; then
          ${cli}/bin/caelestia wallpaper -f ${wallpaper} \
            || echo "caelestia: could not seed the wallpaper" >&2
        fi
      '';

      # Crimson Ronin's GTK theme for GTK 3 apps — Thunar, and Firefox's
      # window chrome — which otherwise fall back to light Adwaita here. GTK 4
      # is left unset on purpose: given a theme package, home-manager takes
      # over gtk-4.0/gtk.css, and ambxst writes its colours into that file.
      # GTK 3's gtk.css stays ambxst's too (home-manager only writes it for
      # gtk3.extraCss).
      #
      # colorScheme writes org.gnome.desktop.interface color-scheme, which
      # xdg-desktop-portal-gtk passes on as the system's light/dark
      # preference (Firefox's prefers-color-scheme follows it). Unset, the
      # portal reports "no preference". Nothing switches it by time of day,
      # so it is dark to match Crimson Ronin. It does not make home-manager
      # write gtk-4.0/gtk.css.
      gtk = {
        enable = true;
        colorScheme = "dark";
        gtk3.theme = {
          name = "CrimsonRonin";
          package = roninGtk;
        };
      };

      wayland.windowManager.hyprland.settings = {
        # `-d` detaches the shell. Without it the CLI stays in the
        # foreground for the session, only to filter the shell's log.
        exec-once = [ "caelestia shell -d" ];

        # Caelestia's panels are Hyprland global shortcuts; they do nothing
        # while it is not running. ambxst binds D, N and Escape too, but
        # toggle-shell reloads Hyprland after stopping it, which drops them.
        bindd = [
          "$mod, SPACE, Caelestia launcher, global, caelestia:launcher"
          "$mod, D, Caelestia dashboard, global, caelestia:dashboard"
          "$mod, N, Caelestia sidebar, global, caelestia:sidebar"
          "$mod, ESCAPE, Caelestia session menu, global, caelestia:session"
          # Animations, blur, gaps, shadows and rounding off; tearing on.
          "$mod SHIFT, G, Toggle game mode (Caelestia), exec, caelestia shell gameMode toggle"

          # Screenshots on Print, split the way macOS splits them: plain
          # opens the region in swappy to mark up and save (Cmd+Shift+4),
          # Ctrl copies the region (Ctrl+Cmd+Shift+4), Shift takes the whole
          # focused monitor (Cmd+Shift+3), to the clipboard with Open and
          # Save in its notification. macOS's own keys are taken here:
          # Super+Shift+3/4 move windows between workspaces. The region
          # picker freezes the screen first, so it captures what was there
          # when the key went down, and clicking a window selects the whole
          # window.
          ", Print, Screenshot a region (swappy), global, caelestia:screenshotFreeze"
          "CTRL, Print, Screenshot a region to the clipboard, global, caelestia:screenshotFreezeClip"
          "SHIFT, Print, Screenshot the monitor to the clipboard, exec, caelestia screenshot"
        ];

        # Crimson Ronin's window borders: a crimson edge that fades back to
        # graphite. Forced over the Catppuccin gradient in hyprland.nix; this
        # also applies while ambxst is running.
        general = {
          "col.active_border" =
            lib.mkForce "rgba(24242Bdd) rgba(720B12ee) rgba(E21A28ff) rgba(24242Bdd) 32deg";
          "col.inactive_border" = lib.mkForce "rgba(24242B66)";
        };
      };
    };
}
