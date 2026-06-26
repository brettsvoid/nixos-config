# User-installed fonts. Nerd Fonts subset chosen because terminals + nvim
# expect the icon glyphs.
_: {
  flake.modules.homeManager.apps-fonts =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nerd-fonts.fira-code
        sketchybar-app-font # app glyphs for sketchybar's front_app item
      ];
    };
}
