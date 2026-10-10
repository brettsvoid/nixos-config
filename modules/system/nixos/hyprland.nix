# System-side Hyprland enablement, xdg portal config, and Wayland-companion
# packages. The user-side wayland.windowManager.hyprland config lives in
# modules/home/desktop/hyprland.nix.
_: {
  flake.modules.nixos.hyprland =
    { pkgs, ... }:
    {
      programs = {
        firefox.enable = true;
        hyprland.enable = true;
        hyprlock.enable = true;
        ambxst.enable = true;
        # File manager (Super+E), and Caelestia's default explorer.
        thunar.enable = true;
      };

      # For Thunar: gvfs for trash, removable drives and network locations;
      # tumbler for thumbnails.
      services = {
        gvfs.enable = true;
        tumbler.enable = true;
      };

      # PAM service for the custom shell's lock screen
      # (home/desktop/quickshell/lock). Not hyprlock's, which would vanish
      # with hyprlock and leave no password able to unlock.
      security.pam.services.custom-shell = { };

      xdg.portal.config.common.default = "*";

      environment.systemPackages = with pkgs; [
        ghostty
        waybar
        fuzzel
        mako
        kitty

        # Sushi, GNOME's Quick Look, behind Space in Thunar (see
        # home/desktop/hyprland.nix). A system package because it is
        # D-Bus-activated, and the session bus reads service files from the
        # system profile.
        #
        # Patched to pass closeIfAlreadyShown, as Nautilus does, so Space
        # again closes the preview; except with SUSHI_FOLLOW, which
        # thunar-quick-look sets when an arrow key moves the preview on, so
        # it stays open at the first or last file.
        #
        # SUSHI_PERSIST keeps Sushi running (about 160 MB) rather than
        # quitting 12 s after a preview, so Space need not wait for it to
        # start. sushi-resize.patch: a preview kept the previous one's size.
        (sushi.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./hyprland/sushi-resize.patch ];
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/sushi.in \
              --replace-fail "const closeIfAlreadyShown = false;" \
                             "const closeIfAlreadyShown = GLib.getenv('SUSHI_FOLLOW') === null;"
          '';
          preFixup = (old.preFixup or "") + ''
            gappsWrapperArgs+=(--set SUSHI_PERSIST 1)
          '';
        }))

        # GTK theme. The icon theme is set in home/desktop/hyprland.nix
        # only: see the note there.
        (catppuccin-gtk.override {
          variant = "mocha";
          accents = [ "mauve" ];
        })
        catppuccin-cursors.mochaDark
      ];
    };
}
