# Neovim with full LSP/formatter/linter toolchain. Lazy.nvim manages plugins
# at runtime; the lua tree under ./config is the static source of truth.
#
# IMPORTANT: ~/.config/nvim itself stays a real directory so lazy.nvim can
# write its lazy-lock.json there. Only the *children* are managed (each as
# an mkOutOfStoreSymlink → live repo path). Editing a .lua file in the
# repo updates nvim immediately; no rebuild needed.
_: {
  flake.modules.homeManager.nvim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      configRoot = "${config.home.homeDirectory}/nixos-config/modules/home/nvim/config";
    in
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        vimdiffAlias = true;

        # Drop the Ruby and Python providers — config is Lua-only and the
        # only Python touchpoint (nvim-dap-python) shells out to an
        # external interpreter rather than using the in-process provider.
        # Adopts the home-manager 26.05 default early; without these our
        # `home.stateVersion = "24.11"` triggers a deprecation warning.
        withRuby = false;
        withPython3 = false;

        extraPackages =
          with pkgs;
          [
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
            typescript-language-server
            pyright
            gopls
            rust-analyzer
            bash-language-server
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

            # Tools used by plugins
            ripgrep
            fd
            lazygit
            tree-sitter
          ]
          # Wayland clipboard helper — Linux-only (Darwin uses pbcopy/pbpaste)
          ++ lib.optionals pkgs.stdenv.isLinux [ wl-clipboard ];
      };

      xdg.configFile = {
        "nvim/init.lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/init.lua";
        "nvim/lua".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lua";
        "nvim/lsp".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/lsp";
        "nvim/queries".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/queries";
        "nvim/README.md".source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/README.md";
      };
    };
}
