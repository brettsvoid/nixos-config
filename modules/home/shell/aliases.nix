_: {
  flake.modules.homeManager.shell-aliases =
    { lib, pkgs, ... }:
    {
      programs.zsh.shellAliases = {
        # Flake management. `nix-rebuild` builds + activates the host
        # config matching `hostname` (no `#name` needed since each host
        # file uses the machine hostname as its config name).
        edit = "cd ~/nixos-config && $EDITOR .";
        nix-rebuild =
          if pkgs.stdenv.isDarwin then
            "sudo darwin-rebuild switch --flake ~/nixos-config"
          else
            "sudo nixos-rebuild switch --flake ~/nixos-config";

        # Editor shortcut (vim/vi handled by programs.neovim's
        # viAlias/vimAlias options)
        vim = "nvim";
        v = "nvim";
        vimdiff = "nvim -d";

        # Modern replacements. ls/grep/find/ps are deliberately NOT
        # aliased — they'd break scripts and pasted commands that expect
        # coreutils flags.
        ls = "eza";
        ll = "eza -la";
        la = "eza -a";
        tree = "eza --tree --level=2";
        df = "duf";
        du = "dust";

        # Git shortcuts (on top of oh-my-zsh git plugin)
        gs = "git status";
        gd = "git diff";
        gds = "git diff --staged";
        gl = "git log --oneline --graph --decorate -20";
        gp = "git push";

        # Quick navigation
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        # tmuxinator
        mux = "tmuxinator";

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
