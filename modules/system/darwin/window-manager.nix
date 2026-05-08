# nix-darwin services for the window-management stack. Replaces the brew-
# launched launchd plists for yabai, skhd, and sketchybar with nix-darwin-
# managed ones, which means edits to those configs (in
# modules/home/darwin/{yabai,skhd,sketchybar}/) take effect on the next
# `darwin-rebuild switch` automatically — no `--restart-service` dance.
#
# Each service uses default config paths (~/.config/yabai/yabairc etc.),
# which we already symlink to the repo via the home-manager modules under
# modules/home/darwin/.
#
# Yabai's scripting addition (window shadow / opacity / padding effects)
# is NOT enabled here — it requires SIP partial-disable + a sudoers rule.
# Tiling works without SA. Re-enable later if you want the visual effects.
_: {
  flake.modules.darwin.window-manager =
    { pkgs, ... }:
    {
      services.yabai = {
        enable = true;
        package = pkgs.yabai;
        # enableScriptingAddition = true;   # opt-in later (needs SIP work)
      };

      services.skhd = {
        enable = true;
        package = pkgs.skhd;
      };

      services.sketchybar = {
        enable = true;
        package = pkgs.sketchybar;
      };
    };
}
