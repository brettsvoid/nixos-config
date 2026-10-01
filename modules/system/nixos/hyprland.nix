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
        # File manager; also what Caelestia opens folders with
        # (general.apps.explorer defaults to thunar). Super+E.
        thunar.enable = true;
      };

      # Thunar's companions: gvfs for trash, removable drives and network
      # locations; tumbler for thumbnails (without it Thunar logs
      # "ThunarThumbnailer: … not activatable" and shows none).
      services = {
        gvfs.enable = true;
        tumbler.enable = true;
      };

      xdg.portal.config.common.default = "*";

      environment.systemPackages = with pkgs; [
        ghostty
        waybar
        fuzzel
        mako
        kitty

        # GNOME's Quick Look, behind Space in Thunar (the custom action in
        # home/desktop/hyprland.nix). A system package because `sushi` only
        # asks the session bus to start org.gnome.NautilusPreviewer, and
        # the bus reads service files from the system profile
        # (/etc/dbus-1/session.conf). Unregistered, it failed with "The
        # name is not activatable".
        #
        # The launcher asks for the file with closeIfAlreadyShown = false,
        # so Space in Thunar only ever showed it. Focus follows the mouse,
        # so once the pointer moved back over Thunar, Space went there and
        # the preview stayed open. Nautilus passes true, which closes the
        # preview when it already shows that file; so does this build,
        # unless SUSHI_FOLLOW is set. thunar-quick-look sets it when the
        # arrow keys move the preview on: at the first or last file the
        # selection stays put, and the preview must stay open.
        #
        # Sushi quits 12 s after its last preview, so most Spaces waited
        # for it to start again: 0.45 s, against 0.15 s once it runs.
        # SUSHI_PERSIST, Sushi's own switch, keeps it running (about
        # 160 MB). thunar-quick-look-keys starts it with the session.
        #
        # sushi-resize.patch: a preview kept the size of the one before it.
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

        # Theme (used by GTK apps under Hyprland). The icon theme comes from
        # home/desktop/hyprland.nix only: see the note there.
        (catppuccin-gtk.override {
          variant = "mocha";
          accents = [ "mauve" ];
        })
        catppuccin-cursors.mochaDark
      ];
    };
}
