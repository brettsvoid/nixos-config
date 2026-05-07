# Modern CLI tools: the everyday "make the shell nice" set. Profile-level dev
# tooling (gh, lazygit, claude-code, language toolchains) lives in profiles/code.
_: {
  flake.modules.homeManager.shell-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        fd
        ripgrep
        jq
        tree
        tldr
        dust
        duf
        procs
        htop
      ];

      programs = {
        eza = {
          enable = true;
          icons = "auto";
          git = true;
          extraOptions = [ "--group-directories-first" ];
        };

        bat = {
          enable = true;
          config.theme = "Catppuccin Mocha";
        };

        zoxide = {
          enable = true;
          enableZshIntegration = true;
        };

        fzf = {
          enable = true;
          enableZshIntegration = true;
          defaultCommand = "fd --type f --hidden --follow --exclude .git";
          defaultOptions = [
            "--height 40%"
            "--border"
          ];
        };
      };
    };
}
