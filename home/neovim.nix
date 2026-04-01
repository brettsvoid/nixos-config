{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      # Build deps (treesitter parser compilation, plugin builds)
      gcc
      gnumake
      cmake
      nodejs
      python3
      git
      curl
      unzip
      luarocks
      lua5_1

      # Language toolchains
      go
      rustc
      cargo

      # LSP servers (replaces Mason on NixOS)
      lua-language-server
      nil # Nix
      nodePackages.typescript-language-server
      pyright
      gopls
      rust-analyzer
      nodePackages.bash-language-server
      terraform-ls
      dockerfile-language-server
      vscode-langservers-extracted # HTML/CSS/JSON/ESLint
      emmet-ls
      tailwindcss-language-server
      biome
      glsl_analyzer
      yaml-language-server

      # Formatters
      stylua
      prettierd
      prettier
      black
      isort
      gofumpt
      goimports-reviser
      golines
      shfmt
      taplo
      rustfmt

      # Linters
      eslint_d
      selene
      shellcheck
      tflint

      # Clipboard (Wayland)
      wl-clipboard

      # Tools used by plugins
      ripgrep
      fd
      lazygit
      tree-sitter
    ];
  };

  xdg.configFile."nvim".source = ./nvim;
}
