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
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${sessions}";
            user = "greeter";
          };
        };
    };
}
