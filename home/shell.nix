{config, pgks, ... }:

{ 
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
   
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };
   
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config";
    };
   
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "z" ];
    }
  };
}
