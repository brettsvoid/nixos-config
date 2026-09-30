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
        # Terminal file manager, for the `yy` function (shell/functions.nix)
        # and yazi.nvim.
        yazi = {
          enable = true;
          # The Macs get the binary from Homebrew (system/darwin/homebrew.nix);
          # they still take the config below.
          package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.yazi else null;
          # shell/functions.nix defines `yy`, and this module's zsh integration
          # would define a second one on the hosts that import both (the
          # Macs).
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

          # Yazi scales images down to this before previewing them (default
          # 600x900), so a maximised pane still showed a 600 px picture. The
          # largest screens: the Odyssey is 2560 wide, the portrait Dell 1920
          # tall. Yazi caches the scaled images in /tmp/yazi-<uid>, keyed by
          # file, not by these limits: clear it after changing them.
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

        # direnv is enabled in profile-code for the binary + nix-direnv.
        # The zsh hook is added there too — no manual `eval $(direnv hook
        # zsh)` needed here.
      };

      # Tool hooks that don't have a home-manager `programs.*` module.
      programs.zsh.initContent = lib.mkOrder 800 ''
        # fnm (Fast Node Manager). Currently provided by homebrew; the
        # `--use-on-cd` switch picks up .nvmrc when entering a project.
        # The version a shell starts on when nothing is pinned comes from
        # fnm's `default` alias, which modules/home/apps/fnm.nix pins.
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
