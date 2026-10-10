{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.shell-aliases =
    { lib, pkgs, ... }:
    {
      programs.zsh.shellAliases = {
        # Flake management. `nix-rebuild`: nh builds the host matching
        # `hostname`, shows a dix diff, then activates. The flake path comes
        # from NH_FLAKE (programs.nh.flake) and nh elevates itself, so no
        # `--flake` or sudo.
        edit = "cd ~/${repoDir} && $EDITOR .";
        nix-rebuild = if pkgs.stdenv.isDarwin then "nh darwin switch" else "nh os switch";

        # Editor shortcuts. programs.neovim's viAlias/vimAlias also install
        # vi and vim as commands, for scripts.
        vim = "nvim";
        v = "nvim";
        vimdiff = "nvim -d";

        # Modern replacements (interactive only: zsh aliases don't expand in
        # scripts). grep/find/ps/cat stay unaliased so their usual flags keep
        # working in muscle memory and pasted commands.
        ls = "eza";
        ll = "eza -la";
        la = "eza -a";
        tree = "eza --tree --level=2";
        df = "duf";
        du = "dust";

        # Git shortcuts. These load after oh-my-zsh's git plugin, so `gl`
        # replaces its `git pull`.
        gs = "git status";
        gd = "git diff";
        gds = "git diff --staged";
        gl = "git log --oneline --graph --decorate -20";
        gp = "git push";

        # Quick navigation
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        # Personal scripts
        commitrefine = "python ~/projects/github.com/brettsvoid/commit-refine/main.py";
        download_website = "wget --mirror -p --convert-links --no-parent";
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        # Linux-only: MSI fan control via isw
        fans = "sudo isw -r";
        fan-boost = "sudo isw -b on";
        fan-quiet = "sudo isw -b off";
      };
    };
}
