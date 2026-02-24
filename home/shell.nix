{ config, pkgs, ... }:

{ 
  # ─── Modern CLI tools ───────────────────────────────────────────────
  home.packages = with pkgs; [
    claude-code     # agentic coding CLI
    fd              # find replacement
    ripgrep         # grep replacement
    jq              # JSON processor
    tree            # directory tree view
    tldr            # simplified man pages
    dust            # disk usage (dust)
    duf             # disk free, better df
    procs           # process viewer, better ps
    htop            # interactive process viewer
  ];

  # ─── Eza (ls replacement) ──────────────────────────────────────────
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
    ];
  };

  # ─── Bat (cat replacement) ─────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
    };
  };

  # ─── Zoxide (smart cd) ────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;   # hooks into zsh so `z` works
  };

  # ─── fzf ───────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;   # ctrl+r history, ctrl+t file, alt+c cd
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--border"
    ];
  };

  # ─── Starship prompt ──────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # Catppuccin Mocha palette
      palette = "catppuccin_mocha";

      format = builtins.concatStringsSep "" [
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$rust"
        "$python"
        "$nodejs"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      directory = {
        style = "bold lavender";
        truncation_length = 4;
        truncation_symbol = "…/";
      };

      git_branch = {
        style = "bold mauve";
        symbol = " ";
      };

      git_status = {
        style = "bold red";
      };

      nix_shell = {
        style = "bold blue";
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };

      rust = {
        style = "bold peach";
        symbol = " ";
      };

      python = {
        style = "bold yellow";
        symbol = " ";
      };

      nodejs = {
        style = "bold green";
        symbol = " ";
      };

      cmd_duration = {
        style = "bold yellow";
        min_time = 2000;
        format = "took [$duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo  = "#f2cdcd";
        pink      = "#f5c2e7";
        mauve     = "#cba6f7";
        red       = "#f38ba8";
        maroon    = "#eba0ac";
        peach     = "#fab387";
        yellow    = "#f9e2af";
        green     = "#a6e3a1";
        teal      = "#94e2d5";
        sky       = "#89dceb";
        sapphire  = "#74c7ec";
        blue      = "#89b4fa";
        lavender  = "#b4befe";
        text      = "#cdd6f4";
        subtext1  = "#bac2de";
        subtext0  = "#a6adc8";
        overlay2  = "#9399b2";
        overlay1  = "#7f849c";
        overlay0  = "#6c7086";
        surface2  = "#585b70";
        surface1  = "#45475a";
        surface0  = "#313244";
        base      = "#1e1e2e";
        mantle    = "#181825";
        crust     = "#11111b";
      };
    };
  };

  # ─── Zsh ───────────────────────────────────────────────────────────
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
      # NixOS
      rebuild = "sudo nixos-rebuild switch --flake /home/brett/nixos-config";
      edit    = "cd ~/nixos-config && $EDITOR .";
      update  = "nix flake update --flake ~/nixos-config";

      # Modern replacements
      cat  = "bat";
      ls   = "eza";
      ll   = "eza -la";
      la   = "eza -a";
      lt   = "eza --tree --level=2";
      grep = "rg";
      find = "fd";
      ps   = "procs";
      df   = "duf";
      du   = "dust";

      # Git shortcuts (on top of oh-my-zsh git plugin)
      gs  = "git status";
      gd  = "git diff";
      gds = "git diff --staged";
      gl  = "git log --oneline --graph --decorate -20";
      gp  = "git push";

      # Quick navigation
      ".."   = "cd ..";
      "..."  = "cd ../..";
      "...." = "cd ../../..";
    };
   
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
    };
  };
}

