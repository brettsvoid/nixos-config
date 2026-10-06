# Nolvus Awakening, the Skyrim modlist, on Linux. The community Nolvus
# Dashboard installs it and Fluorine Manager (Mod Organizer 2 ported to Linux)
# runs it. https://github.com/sableeyed/NolvusDashboard
#
# Both are prebuilt glibc binaries, and the Dashboard bundles Chromium, so they
# run in an FHS env. This module owns that env and a "Nolvus Awakening" entry
# in Fuzzel and the game library; the rest is state:
#
#   /games/Nolvus     the Dashboard, for installs and updates:
#                     nolvus-env -c 'cd /games/Nolvus && ./NolvusDashboard'
#                     Its Play button starts Fluorine without the FUSE env
#                     below; use the menu entry (nolvus-awakening) to play.
#   /games/NA         the instance. The Dashboard records it as Fluorine's
#                     CurrentInstance, so Fluorine opens straight into it.
#   ~/.local/share/fluorine           Fluorine, installed by the Dashboard
#   ~/.local/share/nolvus-awakening   box art and icon, cropped from the
#                                     instance's MO2/splash.png
_: {
  flake.modules.homeManager.apps-nolvus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      art = "${config.xdg.dataHome}/nolvus-awakening";

      mkEnv =
        name: extraBwrapArgs:
        pkgs.buildFHSEnv {
          inherit name extraBwrapArgs;
          targetPkgs =
            p: with p; [
              # Dashboard
              dotnet-runtime_9
              icu
              fontconfig
              freetype
              zlib
              lz4
              stdenv.cc.cc.lib
              # its Chromium
              nss
              nspr
              atk
              at-spi2-atk
              at-spi2-core
              cups
              libdrm
              libgbm
              alsa-lib
              dbus
              expat
              pango
              cairo
              glib
              libx11
              libxcb
              libxcomposite
              libxdamage
              libxext
              libxfixes
              libxrandr
              libxkbcommon
              # Loaded at runtime, so missing from the ELF NEEDED entries:
              # Avalonia's X11 and GTK libraries, libudev for Chromium (which
              # crashes on purpose without it), and OpenSSL for Fluorine's Qt
              # (its Wine setup fails with "TLS initialization failed").
              libice
              libsm
              libxcursor
              libxi
              gtk3
              vulkan-loader
              udev
              openssl
              # Fluorine
              libGL
              libglvnd
              wayland
              # tools they call
              xrandr
              mesa-demos
              pciutils
              protontricks
              winetricks
            ];
          # NixOS keeps the GPU driver outside /usr/lib; Steam's FHS env adds
          # these paths too.
          profile = ''
            export DOTNET_ROOT=${pkgs.dotnet-runtime_9}/share/dotnet
            export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
          '';
          runScript = "bash";
        };

      # For the Dashboard, and for Fluorine's Wine prefix setup (Settings →
      # Compatibility), which the env below breaks.
      nolvus-env = mkEnv "nolvus-env" [ ];

      # For playing. Fluorine merges the mods over the game's Data folder with a
      # FUSE mount. The sandbox sets no_new_privs, so the setuid fusermount3
      # can't mount; libfuse first tries mount() itself, which the kernel allows
      # in the sandbox's user namespace with CAP_SYS_ADMIN there (not on the
      # host). bwrap makes it ambient, so children inherit it, and the Steam
      # Runtime's own bwrap then refuses to start ("Unexpected capabilities but
      # not setuid"). Game launches survive that, as Fluorine wraps them in
      # `unshare --user --mount -r` for the saves bind mount, and bwrap only
      # objects to capabilities when it isn't uid 0; prefix setup doesn't.
      nolvus-env-fuse = mkEnv "nolvus-env-fuse" [
        "--cap-add"
        "CAP_SYS_ADMIN"
      ];

      # buildFHSEnv's sandbox dies with its parent, and Fuzzel and rofi exit
      # as soon as they have started it, so detach it into its own session
      # (as game-launcher does for Steam).
      nolvus-awakening = pkgs.writeShellApplication {
        name = "nolvus-awakening";
        runtimeInputs = [
          pkgs.util-linux
          nolvus-env-fuse
        ];
        text = ''
          exec setsid -f nolvus-env-fuse -c ${config.xdg.dataHome}/fluorine/bin/fluorine-manager
        '';
      };
    in
    {
      home.packages = [
        nolvus-env
        nolvus-awakening
      ];

      xdg.desktopEntries.nolvus-awakening = {
        name = "Nolvus Awakening";
        comment = "Skyrim modlist, through Fluorine Manager";
        exec = lib.getExe nolvus-awakening;
        icon = "${art}/icon.png";
        categories = [ "Game" ];
      };

      local.gameLauncher.entries = [
        {
          title = "Nolvus Awakening";
          launch_command = lib.getExe nolvus-awakening;
          path_box_art = "${art}/box-art.jpg";
        }
      ];
    };
}
