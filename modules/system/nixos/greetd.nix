# tuigreet on top of greetd, providing a Hyprland Wayland session.
# Replaces GDM/GNOME with a minimal terminal-based login.
_: {
  flake.modules.nixos.greetd =
    { pkgs, ... }:
    {
      # Needed for services.xserver.videoDrivers (NVIDIA module). xserver itself
      # is not used as a session; Hyprland is Wayland.
      services.xserver.enable = true;

      services.greetd =
        let
          sessions = pkgs.linkFarm "greeter-sessions" [
            {
              name = "hyprland.desktop";
              path = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
            }
          ];
        in
        {
          enable = true;
          settings.default_session = {
            # pkgs.tuigreet, not pkgs.greetd.tuigreet: nixpkgs moved tuigreet to
            # the top level between the 2026-05-07 and 2026-07-27 revs, and
            # `pkgs.greetd` is now the greetd derivation itself rather than an
            # attrset of the greeters.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${sessions}";
            user = "greeter";
          };
        };
    };
}
