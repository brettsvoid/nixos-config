_: {
  flake.modules.homeManager.shell-zsh = {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;

      history = {
        size = 10000;
        save = 10000;
        ignoreAllDups = true; # subsumes ignoreDups (consecutive-only)
        share = true;
      };

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
    };
  };
}
