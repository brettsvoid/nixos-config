# Modern CLI tools: the everyday "make the shell nice" set. Dev tooling
# (lazygit, language toolchains, …) lives in modules/profiles/code.nix.
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
        # Terminal file manager, for the `yy` function (shell/functions.nix)
        # and yazi.nvim.
        yazi = {
          enable = true;
          # The Macs get the binary from Homebrew (system/darwin/homebrew.nix);
          # they still take the config below.
          package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.yazi else null;
          # Off: shell/functions.nix already defines `yy`, and this would
          # redefine it on the Macs (the hosts that import both).
          enableZshIntegration = false;

          # T fills the whole window with the preview pane, and restores it.
          plugins.toggle-pane = pkgs.yaziPlugins.toggle-pane;
          keymap.mgr.prepend_keymap = [
            {
              on = "T";
              run = "plugin toggle-pane max-preview";
              desc = "Maximise or restore the preview pane";
            }
          ];

          # Yazi scales previews down to this (default 600x900). Sized for
          # the largest screens: the Odyssey is 2560 wide, the portrait Dell
          # 1920 tall. The cached previews in /tmp/yazi-<uid> ignore these
          # limits: clear it after changing them.
          settings.preview = {
            max_width = 2560;
            max_height = 1920;
          };
        };

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

        # direnv, nix-direnv and the zsh hook come from profile-code.
      };

      # Tool hooks that don't have a home-manager `programs.*` module.
      programs.zsh.initContent = lib.mkOrder 800 ''
        # fnm (Fast Node Manager), from Homebrew. `--use-on-cd` picks up a
        # project's .nvmrc; elsewhere the `default` alias applies, which
        # modules/home/apps/fnm.nix pins.
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
