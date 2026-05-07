# Universal home-manager baseline. Username and homeDirectory live in the host
# file (they vary per platform: /home/brett on Linux, /Users/brett on Darwin).
_: {
  flake.modules.homeManager.base = {
    home.stateVersion = "24.11";
    programs.home-manager.enable = true;
    home.sessionVariables.EDITOR = "nvim";
  };
}
