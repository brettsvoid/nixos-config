# Modern CLI tools: the everyday "make the shell nice" set. Profile-level dev
# tooling (gh, lazygit, claude-code, language toolchains) lives in profiles/code.
_: {
  flake.modules.homeManager.shell-tools =
    { lib, pkgs, ... }:
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

        # direnv is enabled in profile-code for the binary + nix-direnv.
        # The zsh hook is added there too — no manual `eval $(direnv hook
        # zsh)` needed here.
      };

      # Tool hooks that don't have a home-manager `programs.*` module.
      programs.zsh.initContent = lib.mkOrder 800 ''
        # fnm (Fast Node Manager). Currently provided by homebrew; the
        # `--use-on-cd` switch picks up .nvmrc when entering a project.
        if command -v fnm &>/dev/null; then
          eval "$(fnm env --use-on-cd)"
        fi

        # envman (per-project env-var manager)
        [ -s "$HOME/.config/envman/load.sh" ] && \
          source "$HOME/.config/envman/load.sh"

        # Docker CLI completions installed by Docker Desktop
        if [[ -d "$HOME/.docker/completions" ]]; then
          fpath=("$HOME/.docker/completions" $fpath)
        fi
      '';
    };
}
