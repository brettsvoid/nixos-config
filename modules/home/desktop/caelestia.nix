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

      # Crimson Ronin ships its palette as a "dynamic" scheme, which the CLI
      # regenerates from the image on every wallpaper change (set_wallpaper in
      # utils/wallpaper.py), losing the hand-tuned colours. A static scheme
      # keeps them, and the CLI reads static schemes only from inside its own
      # package, hence the override.
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
            # suspend-then-hibernates at 10. There is no hibernate here (zram
            # only, no swap partition) and a gaming desktop should not suspend
            # by itself.
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
          # defaults call logind directly; session-exit (desktop-session-restore)
          # saves the open apps for the next login, then has hyprshutdown close
          # them before Hyprland exits.
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
          # Each defaults to on (`check` in utils/theme.py) and rewrites that
          # app's config on every scheme or wallpaper change, GTK and Qt
          # included, which home-manager also writes. Off, so only the shell
          # takes the palette.
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

      # Crimson Ronin's GTK theme for GTK 3 apps (Thunar, Firefox's window
      # chrome), which otherwise fall back to light Adwaita. GTK 4 is left
      # unset on purpose: given a theme package, home-manager takes over
      # gtk-4.0/gtk.css, which ambxst writes its colours into. GTK 3's gtk.css
      # stays ambxst's too (home-manager writes it only for gtk3.extraCss).
      #
      # colorScheme sets org.gnome.desktop.interface color-scheme, which
      # xdg-desktop-portal-gtk reports as the light/dark preference (Firefox's
      # prefers-color-scheme follows it); unset, it reports none. It does not
      # make home-manager write gtk-4.0/gtk.css.
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
          # Print screenshots are desktop-screenshots', under any shell.
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
