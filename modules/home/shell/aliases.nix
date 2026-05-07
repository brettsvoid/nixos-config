_: {
  flake.modules.homeManager.shell-aliases =
    { lib, pkgs, ... }:
    {
      programs.zsh.shellAliases = {
        # Flake management
        edit = "cd ~/nixos-config && $EDITOR .";
        update = "nix flake update --flake ~/nixos-config";
        rebuild =
          if pkgs.stdenv.isDarwin then
            "darwin-rebuild switch --flake ~/nixos-config"
          else
            "sudo nixos-rebuild switch --flake ~/nixos-config";

        # Modern replacements
        cat = "bat";
        ls = "eza";
        ll = "eza -la";
        la = "eza -a";
        lt = "eza --tree --level=2";
        grep = "rg";
        find = "fd";
        ps = "procs";
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
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        # Linux-only: MSI fan control via isw
        fans = "sudo isw -r";
        fan-boost = "sudo isw -b on";
        fan-quiet = "sudo isw -b off";
      };
    };
}
